# Description : This script is used to place the PetaLinux boot components in the SD card.
# Creator : Ronaldo Tsela
# Date    : 12/4/2024
# Last Modification : 26/4/2024

if [ -z "$1" ]; then
    echo "Usage : $0 <project-path>"
    exit 1
fi

path="$1"

cd $path/system

# Copy boot components to BOOT partition
cp ./BOOT.BIN ./image.ub ./boot.scr ./system.dtb /media/$USER/BOOT

# Extract the root file system to ROOTFS partition
mkdir -p ./tmp
sudo mount /dev/mmcblk0p2 ./tmp
cd ./tmp
sudo tar -xvf ../rootfs.tar.gz .

# Create a data folder and populate with images
sudo mkdir -p ./data
sudo cp $path/data/raw/* ./data

# Synchronize and unmount
sync
cd ../
sudo umount /dev/mmcblk0p2

# Clean and exit
sudo rm -r ./tmp

echo "SD Memory card is ready!"
