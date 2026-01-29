#!/bin/bash
# -*- coding: utf-8 -*-
#
#  setup_mirror.sh
#
#  Copyright 2026 Thomas Castleman <batcastle@draugeros.org>
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
if [ "$1" == "" ]; then
    echo "Please provide (sub)-domain mirror will be accessable at"
    exit 1
fi
if [ "$EUID" != "0" ]; then
    echo "Please run this script as root."
    exit 1
fi
domain="$1"
local_path="/var/www/download_mirror/"
rsync_script="#!/bin/sh
/usr/bin/rsync -azvur --progress rsync://rsync.draugeros.org/download $local_path"
nginx_config="server {
    listen 80;

    server_name $domain;

    root $local_path;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to displaying a 404.
        try_files \$uri \$uri/ =404;
        autoindex on;
        autoindex_exact_size on;
        autoindex_localtime off;
    }
}"
# nginx_config_ssl="server {
#     listen 443 ssl http2;
#     listen [::]:443 ssl http2;
#
#     server_name $domain;
#
#     include snippets/ssl-params.conf;
#     include snippets/ssl/de.download.draugeros.org.conf;
#
#     root $local_path;
#
#     location / {
#         # First attempt to serve request as file, then
#         # as directory, then fall back to displaying a 404.
#         try_files \$uri \$uri/ =404;
#         autoindex on;
#         autoindex_exact_size on;
#         autoindex_localtime off;
#     }
# }"
if [ ! -d /etc/cron.daily/ ]; then
    echo "Is a crontab agent (such as anacron or systemd-cron) installed?"
    exit 1
fi
echo "$rsync_script" > /etc/cron.daily/draugeros_rsync_sync.sh
chmod +x /etc/cron.daily/draugeros_rsync_sync.sh
mkdir -p "$local_path"
to_install=""
if [ ! -f /usr/bin/rsync ]; then
    to_install="rsync"
fi
if [ ! -f /usr/sbin/nginx ]; then
    if [ "$to_install" == "" ]; then
        to_install="nginx"
    else
        to_install="$to_install nginx"
    fi
fi
if [ "$to_install" != "" ]; then
    echo "Please install the following dependencies, then rerun this script:"
    echo "$to_install"
    exit 1
fi
echo "================================="
echo "PERFORMING INITIAL SYNC!"
echo "================================="
/etc/cron.daily/draugeros_rsync_sync.sh
echo "================================="
echo "PERFORMING HASH VERIFICATION!"
echo "================================="
ISOs=$(ls $local_path/ISOs)
for each in $(ls $local_path/hash_files); do
    to_verify=$(echo "$ISOs" | grep "$each")
    if [ $(md5sum $local_path/ISOs/$to_verify | awk '{print $1}') != $(awk '{print $1}' $local_path/hash_files/$each/MD5.txt) ]; then
        echo "MD5 DOES NOT MATCH FOR $to_verify!"
        exit 1
    else
        echo "MD5 for $to_verify is correct."
    fi
    if [ $(sha1sum $local_path/ISOs/$to_verify | awk '{print $1}') != $(awk '{print $1}' $local_path/hash_files/$each/SHA1.txt) ]; then
        echo "SHA1 DOES NOT MATCH FOR $to_verify!"
        exit 1
    else
        echo "SHA1 for $to_verify is correct."
    fi
    if [ $(sha256sum $local_path/ISOs/$to_verify | awk '{print $1}') != $(awk '{print $1}' $local_path/hash_files/$each/SHA256.txt) ]; then
        echo "SHA256 DOES NOT MATCH FOR $to_verify!"
        exit 1
    else
        echo "SHA256 for $to_verify is correct."
    fi
done
echo "ALL HASHES ARE VERIFIED GOOD!"
echo "================================="
echo "SETTING UP NGINX!"
echo "================================="
echo "$nginx_config" > /etc/nginx/sites-available/downloads_mirror.conf
chmod 644 /etc/nginx/sites-available/downloads_mirror.conf
chown root:root /etc/nginx/sites-available/downloads_mirror.conf
ln -s /etc/nginx/sites-available/downloads_mirror.conf /etc/nginx/sites-enabled/downloads_mirror.conf
nginx -t
result="$?"
echo "================================="
echo "================================="
if [ "$result" != "0" ]; then
    echo "It appears NGINX had a configuration error. I am not capable of fixing this error. Please correct the error, then restart NGINX.
Once done, make sure your firewall has port 80 open and exposed to the internet, and your mirror will be ready"
else;
    systemctl restart nginx
    echo "Your mirror is now ready and available! Please make sure your firewall has port 80 open and exposed to the internet!"
fi
echo "Simply test your mirror by going to your domain: http://$domain"
echo "If working, please send the domain to the Drauger OS developers and they may include it in our download mirror network!"
exit $result
