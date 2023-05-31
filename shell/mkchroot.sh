#!/bin/bash
# -*- coding: utf-8 -*-
#
#  mkchroot.sh
#  
#  Copyright 2023 Thomas Castleman <batcastle@draugeros.org>
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
        if [ "$XDG_SESSION_TYPE" == "tty" ]; then
                builtin read -p "$1 :  " output
        else
                output=$(zenity --entry --text="$1")
        fi
        builtin echo "$output"
}


function notify ()
{
        if [ "$XDG_SESSION_TYPE" == "tty" ]; then
                wall "$1"
        else
                notify-send --app-name="mkchroot" "mkchroot" "$1"
        fi
}


function cmd_chroot ()
{
	output=0
	connect udev "$CHROOT_LOCATION"/dev -t devtmpfs -o mode=0755,nosuid
	connect devpts "$CHROOT_LOCATION"/dev/pts -t devpts -o mode=0620,gid=5,nosuid,noexec
	connect shm "$CHROOT_LOCATION"/dev/shm -t tmpfs -o mode=1777,nosuid,nodev
	connect proc "$CHROOT_LOCATION"/proc -t proc -o nosuid,noexec,nodev
	connect sys "$CHROOT_LOCATION"/sys -t sysfs -o nosuid,noexec,nodev,ro
	connect tmp "$CHROOT_LOCATION"/tmp -t tmpfs -o nosuid,nodev,strictatime,mode=1777
	connect_bind /run "$CHROOT_LOCATION"/run
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
	root rm -rf "$CHROOT_LOCATION"
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
        mkdir -p $HOME/.config/drauger
        CHROOT_PREFIX=$(ask "What is the folder you want your chroots stored in?")
        CHROOT_PREFIX=${CHROOT_PREFIX:-"$HOME"}
        KERNEL=$(ask "What kernel would you like to use? Default is linux-drauger.")
        KERNEL=${KERNEL:-"linux-drauger"}
        builtin echo -e "# mkchroot config
# Don't end file paths with forward-slashes
# Chroot location
CHROOT_PREFIX=$CHROOT_PREFIX
# Kernel to use
KERNEL=$KERNEL" > $HOME/.config/drauger/mkchroot.conf
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
if [ "$XDG_SESSION_TYPE" != "tty" ]; then
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
UBUNTU_CODENAME=$(curl https://raw.githubusercontent.com/drauger-os-development/development-scripts/master/assets/release_bases.conf 2>/dev/null | grep "$CODENAME" | sed 's/=/ /g' | awk '{print $2}')

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

# install ca-certificates for HTTPS repos, gnupg for repo signing, flatpak for flatpak apps
cmd_chroot apt-get install -o Dpkg::Options::="--force-confold" --force-yes -y ca-certificates gnupg

# set sources
cd "$CHROOT_LOCATION/etc/apt"
root rm sources.list
curl https://raw.githubusercontent.com/drauger-os-development/development-scripts/master/assets/sources.list 2>/dev/null | sed "s/{{ ubu_release }}/$UBUNTU_CODENAME/g" | sed "s/{{ release }}/$CODENAME/g" | sudo tee sources.list 1>/dev/null

# add GPG keys
gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys 821EFFB62DEFB024
gpg --export 821EFFB62DEFB024 | sudo tee "$CHROOT_LOCATION/etc/apt/trusted.gpg.d/drauger_os_main.gpg" 2>/dev/null 1>/dev/null

# add i386 support on AMD64
if [ "$ARCH" == "amd64" ]; then
	cmd_chroot dpkg --add-architecture i386
fi

# update chroot to Drauger OS packages.
cmd_basic_chroot apt-get update
cmd_chroot apt-get -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated dist-upgrade

# set keyboard config options
curl https://raw.githubusercontent.com/drauger-os-development/development-scripts/master/assets/preseed.conf 2>/dev/null | sudo tee "$CHROOT_LOCATION"/preseed.conf
cmd_chroot debconf-set-selections preseed.conf
root rm -v "$CHROOT_LOCATION"/preseed.conf

# install apt package installation list, and kernel
to_install_list="$(curl https://raw.githubusercontent.com/drauger-os-development/development-scripts/master/assets/install-apt.list 2>/dev/null)"
# avail_list=$(cmd_basic_chroot apt-cache search . | awk '{print $1}')
# pkg_list=()
# not_installed=()
# install_list=()
# for each in ${to_install_list[@]}; do
# 	if $(echo "$each" | grep -q ":amd64$"); then
# 		each=$(echo "$each" | sed 's/:/ /g' | awk '{print $1}')
# 	fi
# 	install_list+=("$each")
# done
# count=0
# for each in $install_list; do
# 	will_install=true
# 	for each1 in $avail_list; do
# 		if [ "$each" == "$each1" ]; then
# 			pkg_list+=("$each")
# 			count=$((count+1))
# 			echo "Planned Install: $each"
# 			will_install=false
# 			break
# 		fi
# 	done
# 	if $will_install; then
# 		not_installed+=("$each")
# 	fi
# done
# if [ "${#pkg_list[@]}" == "0" ]; then
# 	echo -e "\n\n\t\t\033[1m### Build of Drauger OS \"$CODENAME\" failed! ###\033[0m"
# 	echo -e "\t\tNo packages needed could be installed."
# 	exit 1
# fi
{
# 	DEBIAN_FRONTEND=noninteractive cmd_chroot apt-get install -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated ${pkg_list[@]} $KERNEL
	DEBIAN_FRONTEND=noninteractive cmd_chroot apt-get install -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated ${to_install_list} $KERNEL
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
pkg_list="$(curl https://raw.githubusercontent.com/drauger-os-development/development-scripts/master/assets/install-flatpak.list 2>/dev/null)"
cmd_chroot flatpak install -y --noninteractive $pkg_list

# remove apt package removal list
pkg_list="$(curl https://raw.githubusercontent.com/drauger-os-development/development-scripts/master/assets/remove-apt.list 2>/dev/null)"
{
	DEBIAN_FRONTEND=noninteractive cmd_chroot apt-get purge -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated $pkg_list
} || {
	DEBIAN_FRONTEND=noninteractive cmd_basic_chroot dpkg --configure -a --force-confold
}

# set plymouth theme
cmd_basic_chroot update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/drauger-theme/drauger-theme.plymouth 100 --slave /usr/share/plymouth/themes/default.grub default.plymouth.grub /usr/share/plymouth/themes/drauger-theme/drauger-theme.grub
cmd_basic_chroot update-alternatives --set default.plymouth /usr/share/plymouth/themes/drauger-theme/drauger-theme.plymouth

# make initamfs
kernel=$(ls "$CHROOT_LOCATION/boot" | grep "-" | sed 's/-/ /g' | awk '{print $2}' | uniq)
cmd_chroot mkinitramfs -o "/boot/initrd.img-$kernel" "$kernel"

# create user
root useradd -R "$CHROOT_LOCATION" --create-home --shell /bin/bash --base-dir /home --groups adm,cdrom,sudo,audio,dip,video,plugdev,pulse,lpadmin live

# configure user
mkdir -v "$CHROOT_LOCATION/home/live/Desktop"
cp -v "$CHROOT_LOCATION/usr/share/applications/system-installer.desktop" "$CHROOT_LOCATION/home/live/Desktop/"
echo "root:toor
live:toor" | sudo chpasswd --root "$CHROOT_LOCATION"
cmd_basic_chroot wget https://github.com/drauger-os-development/development-scripts/raw/master/assets/Drauger_OS_Xfce_Panel_Profile.tar.bz2
cmd_basic_chroot wget https://github.com/drauger-os-development/development-scripts/raw/master/assets/config_folder.tar.xz
cmd_basic_chroot su live -c xfce4-panel-profiles load ./Drauger_OS_Xfce_Panel_Profile.tar.bz2
cmd_basic_chroot tar -xvf config_folder.tar.xz -C /home/live
echo -e 'pcm.!default pulse\nctl.!default pulse' | sudo tee "$CHROOT_LOCATION/home/live/.asoundrc"
cmd_basic_chroot drauger-wallpapers-override

# other settings
echo "[SeatDefaults]
autologin-user-timeout=0
autologin-user=live
user-session=xfce
allow-guest=true
greeter-session=slick-greeter" | sudo tee "$CHROOT_LOCATION/etc/lightdm/lightdm.conf"
echo "[Greeter]
theme-name=Nocturn
icon-theme-name=Papirus-Dark
activate-numlock=true
show-power=false" | sudo tee "$CHROOT_LOCATION/etc/lightdm/slick-greeter.conf"

# clean up
root rm -v "$CHROOT_LOCATION/Drauger_OS_Xfce_Panel_Profile.tar.bz2"
root rm -v "$CHROOT_LOCATION/config_folder.tar.xz"
DEBIAN_FRONTEND=noninteractive cmd_basic_chroot apt autopurge -y -o Dpkg::Options::="--force-confold" --allow-unauthenticated
cmd_basic_chroot apt clean

# notify user of completed chroot
echo -e "\n\n\t\t\033[1m### Build of Drauger OS \"$CODENAME\" completed! ###\033[0m"
notify "### Build of Drauger OS \"$CODENAME\" completed! ###"

if [ "${#not_installed[@]}" != "0" ]; then
        echo -e "\n\n\t\t\033[1m### Some packages could not be installed. ###\033[0m"
        for each in ${not_installed[@]}; do
		echo " - $each"
	done
fi
