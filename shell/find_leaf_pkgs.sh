#!/bin/bash
# -*- coding: utf-8 -*-
#
#  find_leaf_pkgs.sh
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


function calc_perc()
{
	perc=$(echo "($1/$2)*100" | bc -l | sed 's/\./ /g' | awk '{print $1}')
	if [ "${#perc}" -gt "3" ]; then
		perc=0
	fi
	echo "$perc"
}


pkgs=$(dpkg -l | grep "^ii" | awk '{print $2}')
total=0
for each in $pkgs; do
	((total++))
done
evaled=0
echo ""
perc=$(calc_perc $evaled $total)
printf "$evaled / $total packages evaluated, $perc%% complete!"
for each in $pkgs; do
	if [ "$(apt-cache rdepends $each 2>/dev/null | tail -n1)" == "Reverse Depends:" ]; then
		echo "$each" >> leafs.list
	fi
	((evaled++))
	perc=$(calc_perc $evaled $total)
	printf "\r$evaled / $total packages evaluated, $perc%% complete!"
done
echo -e "\n\nComplete! You can find the list of leaf-packages in \`leafs.list'"
