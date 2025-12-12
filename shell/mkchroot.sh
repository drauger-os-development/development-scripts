#!/bin/bash
# -*- coding: utf-8 -*-
#
#  mkchroot.sh
#
#  Copyright 2025 Thomas Castleman <batcastle@draugeros.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#
#
set -e


function ask ()
{
		if [ "$MKCHROOT_HEADLESS_MODE" == "" ]; then
			if [ "$XDG_SESSION_TYPE" == "tty" ]; then
					builtin read -p "$1 :  " output
			else
					output=$(zenity --entry --text="$1")
			fi
		else
			if $(echo "$1" | grep -q "chroots stored in"); then
				output="$MKCHROOT_STORAGE_FOLDER"
			elif $(echo "$1" | grep -q "kernel"); then
				output="$MKCHROOT_KERNEL"
			elif $(echo "$1" | grep -q "coreutils"); then
				output="$MKCHROOT_COREUTILS"
			fi
		fi
        builtin echo "$output"
}


function notify ()
{
        if [ "$XDG_SESSION_TYPE" == "tty" ] || [ "$MKCHROOT_HEADLESS_MODE" != "" ]; then
                wall "$1"
        else
                notify-send --app-name="mkchroot" "mkchroot" "$1"
        fi
}


function cmd_chroot ()
{
	output=0
# 	connect udev "$CHROOT_LOCATION"/dev -t devtmpfs -o mode=0755,nosuid
	connect_bind /dev "$CHROOT_LOCATION"/dev #-t devtmpfs -o mode=0755,nosuid
# 	connect devpts "$CHROOT_LOCATION"/dev/pts -t devpts -o mode=0620,gid=5,nosuid,noexec
	connect_bind /dev/pts "$CHROOT_LOCATION"/dev/pts #-t devpts -o mode=0620,gid=5,nosuid,noexec
# 	connect shm "$CHROOT_LOCATION"/dev/shm -t tmpfs -o mode=1777,nosuid,nodev
	connect_bind /dev/shm "$CHROOT_LOCATION"/dev/shm #-t tmpfs -o mode=1777,nosuid,nodev
# 	connect proc "$CHROOT_LOCATION"/proc -t proc -o nosuid,noexec,nodev
	connect_bind /proc "$CHROOT_LOCATION"/proc #-t proc -o nosuid,noexec,nodev
# 	connect sys "$CHROOT_LOCATION"/sys -t sysfs -o nosuid,noexec,nodev,ro
	connect_bind /sys "$CHROOT_LOCATION"/sys #-t sysfs -o nosuid,noexec,nodev,ro
# 	connect tmp "$CHROOT_LOCATION"/tmp -t tmpfs -o nosuid,nodev,strictatime,mode=1777
	connect_bind /tmp "$CHROOT_LOCATION"/tmp #-t tmpfs -o nosuid,nodev,strictatime,mode=1777
	connect_bind /run "$CHROOT_LOCATION"/run
	root cp "$CHROOT_LOCATION"/etc/resolv.conf "$CHROOT_LOCATION"/etc/resolv.conf.bak
	connect_bind /etc/resolv.conf "$CHROOT_LOCATION"/etc/resolv.conf
	{
		cmd_basic_chroot $@
	} || {
		output=$?
	}
	full_disconnect
	return $output
}


function full_disconnect ()
{
	disconnect "$CHROOT_LOCATION"/dev/pts
	disconnect "$CHROOT_LOCATION"/dev/shm
	disconnect "$CHROOT_LOCATION"/dev
	disconnect "$CHROOT_LOCATION"/proc
	disconnect "$CHROOT_LOCATION"/sys
	disconnect "$CHROOT_LOCATION"/tmp
	disconnect "$CHROOT_LOCATION"/run
	disconnect "$CHROOT_LOCATION"/etc/resolv.conf
	if [ -f "$CHROOT_LOCATION"/etc/resolv.conf ]; then
		if [ "$(cat $CHROOT_LOCATION/etc/resolv.conf.bak)" != "$(cat $CHROOT_LOCATION/etc/resolv.conf)" ]; then
			root mv "$CHROOT_LOCATION"/etc/resolv.conf.bak "$CHROOT_LOCATION"/etc/resolv.conf
		else
			root rm "$CHROOT_LOCATION"/etc/resolv.conf.bak
		fi
	fi
}


function connect ()
{
	root mount "$@"
}


function connect_bind ()
{
	root mount --bind "$1" "$2"
}


function disconnect ()
{
	root umount "$1" || root umount -l "$1" || return 0
}


function cmd_basic_chroot ()
{
	root chroot "$CHROOT_LOCATION" $@ || return $?
}


function root ()
{
	# I REALLY feel uncomfortable with this function. But it works how it should
	# Do not use this function to gain root privs, while also handling a pipe,
	# Data will not be passed correctly through the pipe.
	if [ "$EUID" != "0" ]; then
		echo -En "$PASS" | sudo -S $@
	else
		$@
	fi
}


function gain_root_privs ()
{
	sudo -K
	if [ "$EUID" != "0" ]; then
		echo "OBTAINING ROOT PRIVLEGES"
		while true; do
			read -rsp "Obtaining root password for $(whoami): " PASS
			echo -e "\n"
			echo -En "$PASS" | sudo -S --prompt="" --validate 2>/dev/null 1>/dev/null
			if [ "$?" == "0" ]; then
				echo -e "ROOT PRIVLEGES OBTAINED"
				break
			fi
			echo -e "Password incorrect. Please, try again.\n" 1>&2
		done
	fi
}


function clean ()
{
	# this function is designed to help clean up failed CHROOT builds
	archs=$(ls "$CHROOT_PREFIX")
	archs_new=()
	count=0
	for each in $archs; do
		archs_new[$count]="$each"
		count=$((count+1))
	done
	if [[ ${#archs_new[@]} == "1" ]]; then
		num=1
	elif [[ ${#archs_new[@]} == "0" ]]; then
		echo "Nothing to clean up..."
		exit
	else
		while true; do
			echo "Which architecture would you like to clean up?"
			count=1
			echo "[0] Exit Program"
			for each in ${archs_new[@]}; do
				echo "[$count] $each"
				count=$((count+1))
			done
			read -p "Architecure number: " num
			if [[ $num =~ [a-zA-Z] ]] || [[ $num -lt 0 ]] || [[ $num -gt $count ]]; then
				echo "Not a valid entry. Please provide the number listed to the left of the architecture."
			elif [ $num == 0 ]; then
				echo "Aborting..."
				exit
			else
				break
			fi
		done
	fi
	CHROOT_LOCATION="$CHROOT_PREFIX/${archs_new[$((num-1))]}"
	ARCH=${archs_new[$((num-1))]}
	### Codename
	archs=$(ls "$CHROOT_LOCATION")
	archs_new=()
	count=0
	for each in $archs; do
		archs_new[$count]="$each"
		count=$((count+1))
	done
	if [[ ${#archs_new[@]} == "1" ]]; then
		num=1
	elif [[ ${#archs_new[@]} == "0" ]]; then
		echo "Nothing to clean up..."
		exit
	else
		while true; do
			echo "Which codename would you like to clean up?"
			count=1
			echo "[0] Exit Program"
			for each in ${archs_new[@]}; do
				echo "[$count] $each"
				count=$((count+1))
			done
			read -p "Codename number: " num
			if [[ $num =~ [a-zA-Z] ]] || [[ $num -lt 0 ]] || [[ $num -gt $count ]]; then
				echo "Not a valid entry. Please provide the number listed to the left of the codename."
			elif [ $num == 0 ]; then
				echo "Aborting..."
				exit
			else
				break
			fi
		done
	fi
	CHROOT_LOCATION="$CHROOT_LOCATION/${archs_new[$((num-1))]}"
	CODENAME=${archs_new[$((num-1))]}
	echo "Cleaning up $ARCH $CODENAME..."
	set +e
	full_disconnect 1>/dev/null 2>/dev/null
	set -e
	gain_root_privs
	root rm -rfv "$CHROOT_LOCATION"
	pid="$!"
	chars=("-" '\' "|" "/")
	count=0
	echo ""
	while [ -e "$CHROOT_LOCATION" ]; do
		printf "\r [%s] Deleting %s %s..." "${chars[$count]}" "$ARCH" "$CODENAME"
		if [[ "$count" == "3" ]]; then
			count=0
		else
			count=$((count+1))
		fi
		sleep 0.1s
	done
	exit
}

if [ -f $HOME/.config/drauger/mkchroot.conf ]; then
        eval $(grep -v '^#' $HOME/.config/drauger/mkchroot.conf)
else
        builtin echo "Running first-time config..."
        if [ "$MKCHROOT_HEADLESS_MODE" == "" ]; then
			mkdir -p $HOME/.config/drauger
		fi
        CHROOT_PREFIX=$(ask "What is the folder you want your chroots stored in?")
        CHROOT_PREFIX=${CHROOT_PREFIX:-"$HOME"}
        KERNEL=$(ask "What kernel would you like to use? Default is linux-drauger.")
        KERNEL=${KERNEL:-"linux-drauger"}
        COREUTILS=$(ask "Would you rather have the Rust coreutils, or the GNU coreutils?")
        COREUTILS=${COREUTILS:-"gnu"}
        if [ "$MKCHROOT_HEADLESS_MODE" == "" ]; then
			builtin echo -e "# mkchroot config
# Don't end file paths with forward-slashes
# Chroot location
CHROOT_PREFIX=$CHROOT_PREFIX
# Kernel to use
KERNEL=$KERNEL
# Coreutils
COREUTILS=$COREUTILS" > $HOME/.config/drauger/mkchroot.conf
		fi
fi

needed=""
if ! $(which debootstrap 1>/dev/null 2>/dev/null); then
        needed="debootstrap"
fi
if ! $(which gpg 1>/dev/null 2>/dev/null); then
        needed="$needed gnupg"
fi
if ! $(which curl 1>/dev/null 2>/dev/null); then
        needed="$needed curl"
fi
if ! $(which sed 1>/dev/null 2>/dev/null); then
        needed="$needed sed"
fi
if ! $(which gawk 1>/dev/null 2>/dev/null); then
        needed="$needed gawk"
fi
if ! $(which grep 1>/dev/null 2>/dev/null); then
        needed="$needed grep"
fi
if ! $(which sudo 1>/dev/null 2>/dev/null); then
        needed="$needed sudo"
fi
if [ "$XDG_SESSION_TYPE" != "tty" ] && [ "$MKCHROOT_HEADLESS_MODE" == "" ]; then
	if ! $(which zenity 1>/dev/null 2>/dev/null); then
    	    needed="$needed zenity"
	fi
	if ! $(which notify-send 1>/dev/null 2>/dev/null); then
    	    needed="$needed libnotify-bin"
	fi
fi

if [[ "$needed" != "" ]]; then
        echo "Error: Missing depedencies. Please install the following packages to use this script." 1>&2
        echo "Depedencies:" 1>&2
        echo "$needed" 1>&2
        exit 2
fi

ARCH="$1"
CODENAME="$2"

if [ "$ARCH" == "AMD64" ] || [ "$ARCH" == "amd64" ] || [ "$ARCH" == "x64" ] || [ "$ARCH" == "" ]; then
        ARCH="amd64"
elif [ "$ARCH" == "-h" ] || [ "$ARCH" == "--help" ]; then
        echo -e "
mkchroot [--help] [ARCH] [CODENAME] [--bypass-warning]
                Pass the Arch and the codename to build a chroot for that version of Drauger OS.

            --bypass-warning      Bypass Ubuntu base warning (must be last argument)
        -c, --clean               Delete chroots
        -h, --help                Print this help dialoge and exit.

"
        exit 0
elif [ "$ARCH" == "-c" ] || [ "$ARCH" == "--clean" ]; then
	clean
else
        ARCH="amd64"
fi


# check if codename exists
dists=$(curl https://apt.draugeros.org/dists/ 2>/dev/null | grep "href" | sed 's/.*="//g' | sed 's:/.*::g' | sed 's/\.\.//g')
dists=$(echo "$dists" | egrep -v "dev|graphics")

if [ "$dists" == "${dists/$CODENAME/}" ] ; then
	echo "Codename $CODENAME not recognized" 1>&2
	exit 2
fi

# check what codename is based on
UBUNTU_CODENAME=$(curl https://download.draugeros.org/build/release_bases.conf 2>/dev/null | grep "$CODENAME" | sed 's/=/ /g' | awk '{print $2}')

echo -e "\t\t### Starting build of Drauger OS \"$CODENAME\", based on Ubuntu \"$UBUNTU_CODENAME\". ###

Please note that \033[1mif this is an alpha, beta, or development release, that the Ubuntu base MAY NOT BE FINAL.\033[0m
This may take some time. Please do not shut down your computer until the process has completed.

"

# visible count down until allow to proceed
if [ "$3" != "--bypass-warning" ]; then
	count=15
	notify "Please read the posted warning before continuing..."
	while [[ $count -gt 0 ]]; do
		printf "\rIf you haven't already, please make sure you read the above statment. You may proceed in %s seconds..." "$count"
		sleep 1s
		count=$((count - 1))
	done
	# newline for seperation
	echo ""
	while true; do
		read -p "Are you sure you want to continue? [yes/NO]: " ans
		if [ "${ans,,}" == "no" ]; then
			echo "Aborting chroot creation . . ."
			exit
		elif [ "${ans,,}" == "yes" ]; then
			break
		else
			echo "Please answer with either 'yes' or 'no'."
		fi
	done
fi

# early-obtain root privs

gain_root_privs

notify "Starting build..."

# Set up folder
CHROOT_LOCATION="$CHROOT_PREFIX/${ARCH^^}/$CODENAME"
mkdir -p "$CHROOT_LOCATION"
root chown root:root "$CHROOT_LOCATION"

# start build
notify "Bootstraping..."
root debootstrap --variant=buildd --arch "$ARCH" "$UBUNTU_CODENAME" "$CHROOT_LOCATION" http://archive.ubuntu.com/ubuntu/

# # Make our user now so we can reserve the UID/GID
# # create user
# root useradd -R "$CHROOT_LOCATION" --create-home --shell /bin/bash --base-dir /home -u 1000 live
# {
# 	root groupmod -R "$CHROOT_LOCATION" -g 1000 live
# } || {
# 	:
# }

# install ca-certificates for HTTPS repos, gnupg for repo signing, flatpak for flatpak apps

# Handle coreutils now
cmd_chroot apt-get update
pkgs=$(cmd_basic_chroot dpkg -l)
if [[ "$COREUTILS" == "gnu" ]]; then
	if $(echo "$pkgs" | grep -q "^ii  rust-coreutils "); then
		{
			cmd_chroot apt-get purge --assume-yes --allow-remove-essential -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated rust-coreutils coreutils-from-uutils
		} || {
			cmd_chroot apt-get purge --assume-yes --allow-remove-essential -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated rust-coreutils
		}
	fi
	pkgs=$(cmd_basic_chroot dpkg -l)
	if $(echo "$pkgs" | grep -qv "^ii coreutils "); then
		{
			cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --assume-yes -y coreutils-from-gnu
		} || {
			cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --assume-yes -y coreutils
		}
	fi
else
	if $(echo "$pkgs" | grep -q "^ii  coreutils ") || $(echo "$pkgs" | grep -q "^ii  gnu-coreutils"); then
		{
			cmd_chroot apt-get purge --assume-yes --allow-remove-essential -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated gnu-coreutils coreutils-from-gnu
		} || {
			cmd_chroot apt-get purge -o Dpkg::Options::="--force-confold" --assume-yes --allow-remove-essential -y coreutils
		}
	fi
	pkgs=$(cmd_basic_chroot dpkg -l)
	if $(echo "$pkgs" | grep -qv "^ii rust-coreutils "); then
		{
			cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --assume-yes -y coreutils-from-uutils
		} || {
			cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --assume-yes -y rust-coreutils
		}
	fi
fi

cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --assume-yes -y ca-certificates gnupg wget

# set sources
cd "$CHROOT_LOCATION/etc/apt"
root rm sources.list
# curl https://download.draugeros.org/build/sources.list 2>/dev/null | sed "s/{{ ubu_release }}/$UBUNTU_CODENAME/g" | sudo tee sources.list 1>/dev/null

debs=$(curl https://apt.draugeros.org/pool/main/d/drauger-sources/ | grep "href" | grep -v "\.\." | awk '{print $2}' | sed 's/\"/ /g' | awk '{print $2}' | sort -V)
debs=$(echo "$debs" | tail -n1)
cmd_chroot wget https://apt.draugeros.org/pool/main/d/drauger-sources/$debs
cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --assume-yes -y /$debs

cmd_chroot apt-get update

# add i386 support on AMD64
if [ "$ARCH" == "amd64" ]; then
	cmd_chroot dpkg --add-architecture i386
fi

# update chroot to Drauger OS packages.
cmd_basic_chroot apt-get update
cmd_chroot apt-get --assume-yes -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated dist-upgrade

# set keyboard config options
curl https://download.draugeros.org/build/preseed.conf 2>/dev/null | sudo tee "$CHROOT_LOCATION"/preseed.conf
cmd_chroot debconf-set-selections preseed.conf
root rm -v "$CHROOT_LOCATION"/preseed.conf

# install apt package installation list, and kernel
to_install_list="$(curl https://download.draugeros.org/build/apt_install.list 2>/dev/null)"
{
# 	DEBIAN_FRONTEND=noninteractive cmd_chroot apt-get install -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated ${pkg_list[@]} $KERNEL
	DEBIAN_FRONTEND=noninteractive cmd_chroot apt-get install --assume-yes -o Dpkg::Options::="--force-confold" --allow-unauthenticated ${to_install_list} $KERNEL
} || {
	DEBIAN_FRONTEND=noninteractive cmd_chroot dpkg --configure -a --force-confold
} || {
	DEBIAN_FRONTEND=noninteractive cmd_basic_chroot dpkg --configure -a --force-confold
}

if [ "${#not_installed[@]}" != "0" ]; then
        echo -e "\n\n\t\t\033[1m### Some packages could not be installed. ###\033[0m"
        for each in ${not_installed[@]}; do
                echo " - $each"
        done
fi

# add Flathub
cmd_chroot flatpak remote-add --system --verbose --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

# install flatpak package list
pkg_list="$(curl https://download.draugeros.org/build/flatpak.list 2>/dev/null)"
cmd_chroot flatpak install -y --noninteractive $pkg_list

# remove apt package removal list
pkg_list="$(curl https://download.draugeros.org/build/apt_remove.list 2>/dev/null)"
{
	DEBIAN_FRONTEND=noninteractive cmd_chroot apt-get purge --assume-yes -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated $pkg_list
} || {
	DEBIAN_FRONTEND=noninteractive cmd_basic_chroot dpkg --configure -a --force-confold
}

# set plymouth theme
cmd_basic_chroot update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/drauger-theme/drauger-theme.plymouth 100 --slave /usr/share/plymouth/themes/default.grub default.plymouth.grub /usr/share/plymouth/themes/drauger-theme/drauger-theme.grub
cmd_basic_chroot update-alternatives --set default.plymouth /usr/share/plymouth/themes/drauger-theme/drauger-theme.plymouth

# make initamfs
kernel=$(ls "$CHROOT_LOCATION/boot" | grep "-" | sed 's/-/ /g' | awk '{print $2}' | uniq)
cmd_chroot mkinitramfs -o "/boot/initrd.img-$kernel" "$kernel"

# configure user
# root groupadd -R "$CHROOT_LOCATION" pulse
# root groupadd -R "$CHROOT_LOCATION" lpadmin
# create user
root useradd -R "$CHROOT_LOCATION" --create-home --shell /bin/bash --base-dir /home -u 1000 --groups adm,cdrom,sudo,audio,dip,video,plugdev live
{
	root groupmod -R "$CHROOT_LOCATION" -g 1000 live
} || {
	:
}
# root usermod -R "$CHROOT_LOCATION" -aG adm,cdrom,sudo,audio,dip,video,plugdev live
mkdir -vp "$CHROOT_LOCATION/home/live/Desktop" "$CHROOT_LOCATION/home/live/Downloads" "$CHROOT_LOCATION/home/live/Music" "$CHROOT_LOCATION/home/live/Documents" "$CHROOT_LOCATION/home/live/Videos" "$CHROOT_LOCATION/home/live/Pictures"
root cp -v "$CHROOT_LOCATION/usr/share/applications/edamame.desktop" "$CHROOT_LOCATION/home/live/Desktop/"
root chmod +x "$CHROOT_LOCATION/home/live/Desktop/edamame.desktop"
cmd_chroot usermod -p "$(echo 'toor' | openssl passwd -1 -stdin)" live
cmd_chroot usermod -p "$(echo 'toor' | openssl passwd -1 -stdin)" root
echo -e 'pcm.!default pulse\nctl.!default pulse' | sudo tee "$CHROOT_LOCATION/home/live/.asoundrc"
{
	cmd_chroot drauger-wallpapers-override
} || {
	echo "Could not run drauger-wallpapers-override. Missing executable?"
}

# other settings
if [ ! -d "$CHROOT_LOCATION/etc/sddm.conf.d" ]; then
	root mkdir -pv "$CHROOT_LOCATION/etc/sddm.conf.d"
fi
if [ "$CODENAME" == "urgal" ]; then
	echo "[General]
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
DisplayServer=X11

[Autologin]
User=live
Session=plasma

[Theme]
Current=breeze
CursorTheme=breeze-dark

[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true" | sudo tee "$CHROOT_LOCATION/etc/sddm.conf.d/settings.conf"
else
	echo "[General]
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
DisplayServer=X11

[Autologin]
User=live
Session=plasmawayland

[Theme]
Current=breeze
CursorTheme=breeze-dark

[Wayland]
EnableHiDPI=true

[X11]
EnableHiDPI=true" | sudo tee "$CHROOT_LOCATION/etc/sddm.conf.d/settings.conf"
fi
echo "drauger-live" | sudo tee "$CHROOT_LOCATION/etc/hostname"
{
	cmd_basic_chroot sudo --user=live gpg --batch --quiet --list-keys
} || {
	:
}

cmd_basic_chroot wget https://download.draugeros.org/build/config.tar.xz
if [[ ! -d "$CHROOT_LOCATION"/home/live/.config ]]; then
	mkdir -vp "$CHROOT_LOCATION"/home/live/.config
	chown -v 1000:1000 "$CHROOT_LOCATION"/home/live/.config
	chmod -v 755 "$CHROOT_LOCATION"/home/live/.config
fi
cmd_basic_chroot tar -xvf config.tar.xz -C /home/live/
root cp -vr "$CHROOT_LOCATION"/home/live/.config/ "$CHROOT_LOCATION"/root/
root rm -v "$CHROOT_LOCATION"/config.tar.xz

{
	disconnect "$CHROOT_LOCATION"/etc/resolv.conf
} || {
	:
}
if [ -f "$CHROOT_LOCATION"/etc/resolv.conf.bak ]; then
	{
		root mv -v "$CHROOT_LOCATION"/etc/resolv.conf.bak "$CHROOT_LOCATION"/etc/resolv.conf
	} || {
		:
	}
fi
if [ -f "$CHROOT_LOCATION"/etc/resolv.conf ]; then
	if [ ! -h "$CHROOT_LOCATION"/etc/resolv.conf ]; then
		root rm -v "$CHROOT_LOCATION"/etc/resolv.conf
		cd "$CHROOT_LOCATION"/etc
		root ln -vs ../run/systemd/resolve/stub-resolv.conf resolv.conf
	fi
else
	cd "$CHROOT_LOCATION"/etc
	root ln -vs ../run/systemd/resolve/stub-resolv.conf resolv.conf
fi

# clean up
DEBIAN_FRONTEND=noninteractive cmd_basic_chroot apt-get autopurge --assume-yes -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated
cmd_basic_chroot apt-get clean

# notify user of completed chroot
echo -e "\n\n\t\t\033[1m### Build of Drauger OS \"$CODENAME\" completed! ###\033[0m"
notify "### Build of Drauger OS \"$CODENAME\" completed! ###"

if [ "${#not_installed[@]}" != "0" ]; then
        echo -e "\n\n\t\t\033[1m### Some packages could not be installed. ###\033[0m"
        for each in ${not_installed[@]}; do
			echo " - $each"
		done
fi
