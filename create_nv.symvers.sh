#!/bin/bash
#
# Copyright (c) 2016 Mellanox Technologies. All rights reserved.
#
# This Software is licensed under one of the following licenses:
#
# 1) under the terms of the "Common Public License 1.0" a copy of which is
#    available from the Open Source Initiative, see
#    http://www.opensource.org/licenses/cpl.php.
#
# 2) under the terms of the "The BSD License" a copy of which is
#    available from the Open Source Initiative, see
#    http://www.opensource.org/licenses/bsd-license.php.
#
# 3) under the terms of the "GNU General Public License (GPL) Version 2" a
#    copy of which is available from the Open Source Initiative, see
#    http://www.opensource.org/licenses/gpl-license.php.
#
# Licensee has the right to choose one of the above licenses.
#
# Redistributions of source code must retain the above copyright
# notice and one of the license notices.
#
# Redistributions in binary form must reproduce both the above copyright
# notice, one of the license notices in the documentation
# and/or other materials provided with the distribution.
#

MOD_SYMVERS=nv.symvers
KVER=${1:-$(uname -r)}

# Create empty symvers file
echo -n "" > $MOD_SYMVERS

nvidia_mod=
for mod in nvidia $(ls /lib/modules/$KVER/updates/dkms/nvidia*.ko 2>/dev/null)
do
	nvidia_mod=$(/sbin/modinfo -F filename -k "$KVER" $mod 2>/dev/null)
	if [ ! -e "$nvidia_mod" ]; then
		continue
	fi
	if ! (nm -o $nvidia_mod | grep -q "__crc_nvidia_p2p_"); then
		continue
	fi

	echo "Getting symbol versions from $nvidia_mod ..."
	while read -r line
	do
		file=$(echo $line | cut -f1 -d: | sed -e 's@\./@@' -e 's@.ko@@' -e "s@$PWD/@@")
		crc=$(echo $line | cut -f2 -d: | cut -f1 -d" ")
		sym=$(echo $line | cut -f2 -d: | cut -f3 -d" " | sed -e 's/__crc_//g')
		echo -e "0x$crc\t$sym\t$file" >> $MOD_SYMVERS
	done < <(nm -o $nvidia_mod | grep "__crc_nvidia_p2p_")

	echo "Created: ${MOD_SYMVERS}"
	exit 0
done

if [ ! -e "$nvidia_mod" ]; then
	echo "-E- Cannot locate nvidia modules!" >&2
	echo "CUDA driver must be installed before installing this package!" >&2
	exit 1
fi

if [ ! -s "$MOD_SYMVERS" ]; then
	echo "-W- Could not get list of nvidia symbols." >&2
fi
