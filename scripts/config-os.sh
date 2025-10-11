#!/bin/bash

# Description : Script to create and configure the PetaLinux OS for the Sobel Edge Detector SoC
# Project     : sobel_pl
# Creator     : Ronaldo Tsela
# Date        : 12/04/2024

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <PetaLinux-tools-path> <Full-path-to-XSA>"
    exit 1
fi

project_name="sobel_soc"

src_dir="$2/sobel_pl/src"
include_dir="$src_dir/include"

# Source PetaLinux tools
source "$1/settings.sh"

# # Create and configure the project directory
cd "$2"
petalinux-create --type project --name $project_name --template zynq --force
cd "./$project_name"

petalinux-config --get-hw-description="$2"

# Initial build
petalinux-build

# === DMA-PROXY DRIVER SETUP ===
petalinux-create --type modules --name dma-proxy --enable --force

# Copy driver source files
cp "$src_dir/dma-proxy.c" "$include_dir/dma-proxy.h" ./project-spec/meta-user/recipes-modules/dma-proxy/files/
cp "$src_dir/system-user.dtsi" ./project-spec/meta-user/recipes-bsp/device-tree/files

# Append header file to recipe
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

