# Description : This script is used to configure the Linux
# environment in order to install and use the PetaLinux tools.
# It installs a series of libraries and applications required
# by PetaLinux tools.
# Note: This script is tailored for Ubuntu 22.04. For other versions, check PetaLinux documentation.
# Creator : marrln
# Date    : October 20, 2025
# Last Modification : October 20, 2025

sudo dpkg --add-architecture i386
sudo apt update
sudo apt-get install -y gcc git make net-tools libncurses-dev tftpd-hpa zlib1g-dev libssl-dev flex bison libselinux1 gnupg wget diffstat chrpath socat xterm autoconf libtool tar unzip texinfo gcc-multilib build-essential libsdl2-dev libglib2.0-dev lib32z1-dev screen pax gzip gawk

# If zlib1g:i386 is still missing, try manual installation as fallback (Stack Overflow solution)
# https://stackoverflow.com/questions/71619099/why-does-the-installation-script-petalinux-does-not-find-zlib1g#75506394
# Remove existing installations for zlib1g-dev
sudo apt remove -y zlib1g-dev:i386
sudo apt remove -y zlib1g-dev
sudo apt autoremove -y
# Install dependency for zlib1g-dev:i386
sudo apt install -y libc6-dev:i386
wget -q http://archive.ubuntu.com/ubuntu/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu9_amd64.deb -O /tmp/zlib1g_amd64.deb
wget -q http://archive.ubuntu.com/ubuntu/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu9_i386.deb -O /tmp/zlib1g_i386.deb
wget -q http://archive.ubuntu.com/ubuntu/pool/main/z/zlib/zlib1g-dev_1.2.11.dfsg-2ubuntu9_i386.deb -O /tmp/zlib1g-dev_i386.deb
sudo dpkg -i /tmp/zlib1g_amd64.deb /tmp/zlib1g_i386.deb /tmp/zlib1g-dev_i386.deb || echo "Manual install failed, try running the installer anyway."
