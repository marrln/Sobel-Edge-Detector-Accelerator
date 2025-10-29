#!/bin/bash

# Description       : Script to create and configure the PetaLinux OS for the Sobel Edge Detector SoC
# Project           : sobel_pl
# Author            : marrln
# Date              : October 23, 2025
# Last Modification : October 23, 2025

# Allow the script to be invoked without arguments by providing sensible
# defaults. If the caller provides arguments, those are used instead.
# These default paths are the typical user locations used during
# development on the reference machine. Change them if you keep your
# PetaLinux tools or XSA elsewhere.
DEFAULT_PETALINUX_DIR="/home/phoebus/Desktop/peta-os"
DEFAULT_XSA_PATH="/home/phoebus/Desktop/sobel_succ/design_1_wrapper.xsa"
project_name="sobel_soc" # Name of the PetaLinux project to create

# PETALINUX tools path (either a directory containing settings.sh or the
# full path to a settings.sh file). We accept either form so the caller
# can pass the top-level Petalinux installation directory or the exact
# settings.sh script path. We prefer an explicit argument ($1) but
# fall back to the default above when none is provided.
if [ -n "$1" ]; then
    PETA_ARG="$1"
else
    PETA_ARG="$DEFAULT_PETALINUX_DIR"
fi

# XSA/hardware description path. The script accepts either the directory
# containing the hardware description or the full .xsa file path. If a
# .xsa file is passed we will set the petalinux hw description to that
# file. If a directory is passed we will use it directly.
if [ -n "$2" ]; then
    XSA_ARG="$2"
else
    XSA_ARG="$DEFAULT_XSA_PATH"
fi

# Resolve the location of the Petalinux 'settings.sh' file. This file
# sets up environment variables and paths required by the petalinux
# commands used later in this script. We check three possibilities in
# order:
#  1) caller passed a full path to settings.sh
#  2) caller passed the Petalinux root directory and settings.sh is at
#     $PETA_ARG/settings.sh
#  3) settings.sh lives under a tools/ subdirectory (common in some
#     installations)
if [ -f "$PETA_ARG" ]; then
    # Caller provided the exact settings.sh path
    PETA_SETTINGS="$PETA_ARG"
elif [ -f "$PETA_ARG/settings.sh" ]; then
    PETA_SETTINGS="$PETA_ARG/settings.sh"
elif [ -f "$PETA_ARG/tools/settings.sh" ]; then
    PETA_SETTINGS="$PETA_ARG/tools/settings.sh"
else
    echo "ERROR: Could not find PetaLinux settings.sh under: $PETA_ARG"
    echo "Looked for: $PETA_ARG/settings.sh and $PETA_ARG/tools/settings.sh"
    echo "Provide the Petalinux install directory or the full settings.sh path as the first argument."
    exit 1
fi

# If XSA_ARG is a file, use its directory as the working folder. If it's a
# directory, use it directly.
if [ -f "$XSA_ARG" ]; then
    # XSA_ARG points to a file: use that file as the hardware description
    # and set the base working directory to its parent folder.
    HW_DESC_PATH="$XSA_ARG"
    BASE_DIR="$(dirname "$XSA_ARG")"
else
    # XSA_ARG is a directory containing the hardware description files
    HW_DESC_PATH="$XSA_ARG"
    BASE_DIR="$XSA_ARG"
fi

# Application source layout is expected under BASE_DIR/sobel_pl/src with
# headers in BASE_DIR/sobel_pl/src/include. This keeps the petalinux
# project self-contained inside the working directory.
src_dir="$BASE_DIR/sobel_pl/src"
include_dir="$src_dir/include"

# Source the Petalinux environment to make commands like petalinux-create
# and petalinux-build available in this shell session.
source "$PETA_SETTINGS"

# # Create and configure the project directory
# Create a fresh petalinux project inside the base folder. The project
# name is chosen above; --force will overwrite an existing project with
# the same name in the current directory if present.
cd "$BASE_DIR"
petalinux-create --type project --name $project_name --template zynq --force
cd "./$project_name"

# Point the petalinux configuration to the hardware description. Passing
# a .xsa file or a directory is both supported by petalinux-config.
petalinux-config --get-hw-description="$HW_DESC_PATH"

# Initial build
petalinux-build

# === DMA-PROXY DRIVER SETUP ===
petalinux-create --type modules --name dma-proxy --enable --force

# Copy driver source files into the new project tree so the kernel module
# recipe can pick them up. This places the C source and header under the
# module recipe files directory and the device-tree fragment under the
# BSP's device-tree files so it gets merged into the final DTB.
cp "$src_dir/dma-proxy.c" "$include_dir/dma-proxy.h" ./project-spec/meta-user/recipes-modules/dma-proxy/files/
cp "$src_dir/system-user.dtsi" ./project-spec/meta-user/recipes-bsp/device-tree/files

# The recipe (bb file) needs to list the extra header file. We use the
# non-interactive 'ed' editor here to insert a line into the recipe so
# that the build system will install the header along with the module
# source. This sequence writes commands into a temporary cmd.txt which
# is consumed by ed.
echo "13i" > cmd.txt
echo "file://dma-proxy.h \ " >> cmd.txt
echo "." >> cmd.txt
echo "w" >> cmd.txt
echo "q" >> cmd.txt

ed ./project-spec/meta-user/recipes-modules/dma-proxy/dma-proxy.bb < cmd.txt

rm cmd.txt

# Build DMA-proxy driver
petalinux-build

# === APPLICATION: sobel-pl ===
petalinux-create --type apps --name sobel-pl --enable --force

# Copy application source and header files
cp "$include_dir/dma-proxy.h" "$include_dir/sobel_pl.h" "$include_dir/pl.h" "$src_dir/sobel_pl.c" "$src_dir/main.c" "$src_dir/pl.c" "$src_dir/Makefile" ./project-spec/meta-user/recipes-apps/sobel-pl/files/

# Append application files to recipe
echo "12i" > cmd.txt
echo "file://dma-proxy.h \ " >> cmd.txt 
echo "file://sobel_pl.h \  " >> cmd.txt
echo "file://sobel_pl.c \ " >> cmd.txt
echo "file://main.c \  " >> cmd.txt
echo "file://pl.c \  " >> cmd.txt
echo "file://pl.h \  " >> cmd.txt
echo "file://Makefile \  " >> cmd.txt
echo "." >> cmd.txt
echo "w" >> cmd.txt
echo "q" >> cmd.txt

ed ./project-spec/meta-user/recipes-apps/sobel-pl/sobel-pl.bb < cmd.txt

rm cmd.txt

# Build application
petalinux-build

# Package BOOT files
petalinux-package --boot --force \
    --fsbl ./images/linux/zynq_fsbl.elf \
    --fpga ./images/linux/system.bit \
    --uboot ./images/linux/u-boot.elf

# Export final boot components to system/
mkdir -p "./system"
cp ./images/linux/{BOOT.BIN,boot.scr,system.dtb,image.ub,rootfs.tar.gz} "./system"

