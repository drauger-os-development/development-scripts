#!/bin/bash
# -*- coding: utf-8 -*-
#
#  monitor-apt-repo.sh
#  
#  Copyright 2020 Thomas Castleman <contact@draugeros.org>
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
# crash if there are any uncaught errors
set -eE
set -o pipefail
# notify of start-up
builtin echo "Started up at $(date)"
# initialize vars used on all systems
R="\033[0;31m"
NC="\033[0m"
conf="False"
db="False"
dists="False"
lists="False"
pool="False"
# get hostname and username for reporting
# we want to run these commands once so that this data is in memory
# that way it's basicly just a matter of retrieving data from memory instead of running a command.
hostname=$(hostname)
username=$(whoami)
# see if our config file exists
if [ -f "$HOME/.config/drauger/monitor-apt-repo.conf" ]; then
	# if it does, load our config
	eval $(grep -v '^#' "$HOME/.config/drauger/monitor-apt-repo.conf")
else
	# if it doesn't run first-time set-up
	builtin echo "Performing first-time set-up . . . "
	# make sure sendmail is installed
	# we use sendmail to handle sending error emails
	if [ -f "$(builtin command -v sendmail)" ]; then
		# we got sendmail, we goot
		builtin echo "sendmail is installed"
	else
		# we don't have sendmail. Notify the user and exit
		builtin echo "sendmail is not installed. Please install it then re-run this script."
		exit 2
	fi
	# prompt the user for settings
	builtin read -rp "What repository should be monitored?: " repo
	builtin read -rp "What email should errors be reported to?: " report_to
	# generate config file
	builtin echo -e "# monitor-apt-repo.sh config\n# Montored Repository\nrepo=$repo\n# Email to report errors to\nreport_to=$report_to\n" > "$HOME"/.config/drauger/monitor-apt-repo.conf
fi
# enter le infinite
while true; do
	{
		# notify of loop start
		builtin echo "Loop start $(date)"
		# curl the repo. Send stderr to the black hole of /dev/null
		content=$(curl "$repo" 2>/dev/null)
		# print the curled data so it can be logged in case the email doesn't send
		builtin echo -e "Curled:\n$content"
		# check each expected folder exists
		# if one of these is absent, grep will throw an error and we go into our catch block
		builtin echo "$content" | grep -q "conf" && conf="True"
		builtin echo "$content" | grep -q "db" && db="True"
		builtin echo "$content" | grep -q "dists" && dists="True"
		builtin echo "$content" | grep -q "lists" && lists="True"
		builtin echo "$content" | grep -q "pool" && pool="True"
	} || {
		# fuck it's the catch block
		# re-curl the repo, capturing the stderr output so that we can see what happened
		content=$(curl "$repo" 2>&1)
		# log var. this is what is sent in the email
		log="$R\t###\tERROR\t###\t\nError with apt repository.$NC\nconf = $conf\ndb = $db\ndists = $dists\nlists = $lists\npool = $pool\n\nCurl output:\n$content\n"
		# this log var is also printed so that if the email doesn't go we still know what happened
		builtin echo -e "$log" 1>&2
		# email the log var to the email in $report_to
		# specify the hostname this is from so that if we have multiple computers monitoring we can more easily tell if this is a local error or something else
		builtin echo -e "Subject: Apt repository error report from $hostname\n\n$log\n." | sendmail -f"$username" "$report_to"
		# wait an extra hour so we don't get flooded with errors
		sleep 1h
	}
	# reset our vars for the next loop
	conf="False"
	db="False"
	dists="False"
	lists="False"
	pool="False"
	# sleep a while so we don't hog CPU resources or clog up the disk
	# went with an hour so the disk will only get a few bytes to a few kilobytes written to it about once an hour, so pretty slowly
	sleep 1h
done
# if we get out here we have huge issues
