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
