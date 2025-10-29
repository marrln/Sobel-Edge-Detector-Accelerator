Scripts README

This folder contains helper scripts used to prepare a PetaLinux project and
build the software components for the Sobel Edge Detector SoC. The three main
scripts are:

- `config-os.sh` - create and configure a PetaLinux project using the
  hardware description (XSA) and project sources.
- `setup-env.sh` - install required system packages and dependencies to run
  Petalinux on Ubuntu 22.04 (must be run with sudo).
 - `setup-sd.sh` - package the build outputs and prepare an SD-card image or
   copy boot files to a target location/device for booting the board.

Usage
-----

1) Prepare your environment

- If you haven't already, make the scripts executable:

  ```bash
  chmod +x config-os.sh setup-env.sh
  ```

2) Install OS packages (optional / required on a fresh VM)

- Run `setup-env.sh` on an Ubuntu 22.04 machine. This installs many packages
  required by PetaLinux (gcc, make, flex, bison, libraries, etc). It must be
  executed with sudo because it installs system packages:

  ```bash
  sudo ./setup-env.sh
  ```

  Notes:
  - The script includes a fallback manual installation for `zlib1g` if the
    multiarch packages are unavailable on your host. If that fails, follow the
    script output and try installing the missing packages manually.

3) Create and configure the PetaLinux project

- Run `config-os.sh`. The script accepts two optional arguments:

  ```bash
  ./config-os.sh [PETA_PATH_or_settings.sh] [XSA_path_or_dir]
  ```

  - If no arguments are provided, the script will use the default paths
    configured inside the script (change them before running if needed).
  - The first argument may be either the Petalinux installation directory or
    the full path to `settings.sh`.
  - The second argument may be the path to the `.xsa` file or the directory
    containing the hardware description.

Examples
--------

- Run with defaults (ensure the defaults in the script match your system):

  ```bash
  ./config-os.sh
  ```

- Run with explicit paths:

  ```bash
  ./config-os.sh /home/phoebus/Desktop/peta-os /home/phoebus/Desktop/sobel_succ/design_1_wrapper.xsa

4) Prepare SD card (optional)

- If a helper script `setup-sd.sh` is present it can package the produced
  boot artifacts (BOOT.BIN, image.ub, system.dtb, etc.) and either create a
  bootable SD image or copy the files to a mounted SD card. Typical usage is:

  ```bash
  chmod +x setup-sd.sh
  ./setup-sd.sh <output-directory-or-device>
  ```

  Notes and safety:
  - Check the contents of `setup-sd.sh` before running: writing directly to
    a block device (e.g. `/dev/sdX`) will erase it. Use the script's dry-run
    mode if available, or pass an output directory first to verify files.
  - You will likely need `sudo` to write an image to a raw device. Prefer
    copying the produced files to a mounted SD card directory when testing.
  ```

Troubleshooting
---------------

- If `petalinux` commands are not found, ensure you sourced the correct
  `settings.sh` file for your Petalinux installation. The script attempts to
  find it automatically, but you can pass it explicitly as the first
  argument.

- Do not run the whole `config-os.sh` under `sudo`. That will start the
  process as root and may create files owned by root which will be difficult
  to manage later. Only use `sudo` when the commands themselves require it.

- If the script fails to find your application sources, make sure your
  sources are present under `BASE_DIR/sobel_pl/src` (the script assumes the
  repository layout described in the project). You can also pass a different
  base directory as the XSA argument.

Files the scripts expect
------------------------

- `sobel_pl/src/`
  - `dma-proxy.c`
  - `sobel_pl.c`
  - `main.c`
  - `pl.c`
  - `Makefile`

- `sobel_pl/src/include/`
  - `dma-proxy.h`
  - `sobel_pl.h`
  - `pl.h`

Contact
-------

If you hit issues, gather the script output and the contents of the `petalinux-build`
log and share them with the project maintainer.
