Note: Have you run this checklist before? If you want to start off with the files created during the last runthrough, skip to step #8

--------------------

1) Download the most recent ISO from DraugerOS.org
2) Clone the [development-scripts](https://github.com/drauger-os-development/development-scripts) repo
```bash
git clone "https://github.com/drauger-os-development/development-scripts"
```
3) Create a working directory.  In that directory, create the CHROOT folder. Create the AMD64 folder inside the CHROOT folder.
```bash
mkdir -p CHROOT/AMD64
```
4) Extract the ISO (right click and select "Extract Here")
5) Decompress filesystem.squashfs into AMD64 folder
```bash
# filesystem.squashfs is located in the live folder within the extracted ISO
sudo unsquashfs -d <path-to>/CHROOT/AMD64/zombi ./filesystem.squashfs
# the -d modifier can have problems sometimes.  If problems occur, unsquashfs in place
# (exclude -d and desination) and move/rename the folder to where it needs to be
```
6) Install arch-install-scripts
```bash
sudo apt install arch-install-scripts
```
7) CHROOT into the ISO
```bash
sudo arch-chroot CHROOT/AMD64/zombi/
```
8) Update the ISO
```bash
apt update
apt upgrade
```
9) Remove old kernels
```bash
# This is an example script
dpkg -l *xanmod*
apt purge linux-headers-5.13.19-xanmod1 linux-image-5.13.19-xanmod1
# in this instance, 5.13.19 is the old kernel version
```
10) Clean up and exit
```bash
apt clean
apt autopurge
exit
```

### version 7.5.1 instructions
11) Run make-iso command from the shell directory inside development-scripts
```bash
# this script only needs to be run once, and then it saves a config file in ~/.config/drauger
./make-iso
# The script may have an error listing some missing packages.  Install any required dependencies listed, then move onto next step.
```

12) Run make-iso command a second time with arguments
```bash
./make-iso amd64 zombi
```

### version 7.6 instructions
11) Run make-iso command from the shell directory inside development-scripts
```bash
# this script only needs to be run once, and then it saves a config file in ~/.config/drauger
./make-iso-repo
# The script may have an error listing some missing packages.  Install any required dependencies listed, then move onto next step.
```

12) Run make-iso command a second time with arguments
```bash
./make-iso-repo amd64 zombi
```


