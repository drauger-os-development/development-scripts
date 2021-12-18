1) Download the most recent ISO from DraugerOS.org
2) Clone the [development-scripts](https://github.com/drauger-os-development/development-scripts) repo
```bash
git clone "https://github.com/drauger-os-development/development-scripts"
```
3) Create a working directory.  In that directory, create the CHROOT folder.
```bash
mkdir CHROOT
```
4) Inside the CHROOT folder, create the AMD64 folder
```bash
cd CHROOT
mkdir AMD64
```
5) Extract the ISO (right click and select "Extract Here")
6) Decompress filesystem.squashfs into AMD64 folder
```bash
# filesystem.squashfs is located in the live folder within the extracted ISO
sudo unsquashfs -d ~/Programming/CHROOT/AMD64/zombi ./filesystem.squashfs
```
7) Install arch-install-scripts
```bash
sudo apt install arch-install-scripts
```
8) CHROOT into the ISO
```bash
sudo arch-chroot ~/Programming/CHROOT/AMD64/zombi/
```
9) Update the ISO
```bash
apt update
apt upgrade
```
10) Remove old kernels
```bash
# This is an example script
dpkg -l *xanmod*
apt purge linux-headers-5.13.19-xanmod1 linux-image-5.13.19-xanmod1
# in this instance, 5.13.19 is the old kernel version
```
11) Clean up and exit
```bash
apt clean
apt autopurge
exit
```
12) Run make-iso command from directory development-scripts was cloned into
```bash
./make-iso
# Install any required dependencies highlighted during script execution
```
13) Run make-iso command a second time with arguments
```bash
./make-iso amd64 zombi
```
