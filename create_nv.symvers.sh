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
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)

MOD_SYMVERS=${SCRIPTPATH}/nv.symvers
KVER=${1:-$(uname -r)}

# Create empty symvers file
echo -n "" > $MOD_SYMVERS

try_compile_nvidia_sources()
{
	local mod=$1; shift

	nv_version=$(/sbin/modinfo -F version -k "$KVER" $mod 2>/dev/null)
	nv_sources=$(/bin/ls -d /usr/src/nvidia-${nv_version}/ 2>/dev/null)
	if [ "X${nv_sources}" == "X" ]; then
		nv_sources=$(/bin/ls -1d /usr/src/nvidia-* 2>/dev/null | tail -1)
	fi
	if [ "X${nv_sources}" == "X" ]; then
		return
	fi

	echo
	echo "Attempting to compile nvidia from $nv_sources sources to build Module.symvers..."
	echo
	local tmpdir=`mktemp -d /tmp/nv.XXXXXX`
	if [ ! -d "$tmpdir" ]; then
		echo "-E- Failed to create a temp directory!" >&2
		exit 1
	fi
	/bin/cp -a $nv_sources $tmpdir
	cd $tmpdir/*
	make -j8 NV_EXCLUDE_BUILD_MODULES='' KERNEL_UNAME=$KVER clean
	if [ $? -ne 0 ]; then
		return
	fi
	make -j8 NV_EXCLUDE_BUILD_MODULES='' KERNEL_UNAME=$KVER modules
	if [ $? -ne 0 ]; then
		return
	fi
	grep "nvidia_p2p_" Module*.symvers > ${MOD_SYMVERS}
	echo "Created: ${MOD_SYMVERS}"
	cd -
	/bin/rm -rf $tmpdir
}

nvidia_mod=
crc_found=0
crc_mod_str="__crc_nvidia_p2p_"
modules_pat="$crc_mod_str|T nvidia_p2p_"
for mod in nvidia $(ls /lib/modules/$KVER/updates/dkms/nvidia*.ko* 2>/dev/null)
do
	nvidia_mod=$(/sbin/modinfo -F filename -k "$KVER" $mod 2>/dev/null)
	if [ ! -e "$nvidia_mod" ]; then
		continue
	fi

	# WA for nm: nvidia.ko.xz: File format not recognized
	case "$nvidia_mod" in
		*ko.xz)
			/bin/cp -fv $nvidia_mod .
			nvidia_mod=$(basename $nvidia_mod | sed -e "s/.xz//g")
			xz -d ${nvidia_mod}.xz
			;;
	esac

	if ! (nm -o $nvidia_mod | grep -q -E "$modules_pat"); then
		continue
	fi

	# On some PPC kernels we might have relative CRCs, so we can't build symvers based on nm output.
	# In that case try to recompile the nvidia driver from source code and get the needed
	# nvidia_p2p_* symbols from the generated Module.symvers file.
	# If we fail to generate Module.symvers, then just build the nv_peer_mem without
	# specifying the nvidia_p2p_ symbol versions.
	if (nm -o $nvidia_mod | grep "$crc_mod_str" | grep -qe "\sR\s*__crc"); then
		echo "-W- Module $nvidia_mod contains relative CRCs, cannot get symbols from it!" >&2
		try_compile_nvidia_sources $nvidia_mod
		break
	fi

	echo "Getting symbol versions from $nvidia_mod ..."
	while read -r line
	do
		if echo "$line" | grep -q "$crc_mod_str"; then
			crc_found=1
		else
			if [ "$crc_found" != 0 ]; then
				continue
			fi
		fi
		file=$(echo $line | cut -f1 -d: | sed -r -e 's@\./@@' -e 's@.ko(\S)*@@' -e "s@$PWD/@@")
		crc=$(echo $line | cut -f2 -d: | cut -f1 -d" ")
		sym=$(echo $line | cut -f2 -d: | cut -f3 -d" " | sed -e 's/__crc_//g')
		echo -e "0x$crc\t$sym\t$file\tEXPORT_SYMBOL\t" >> $MOD_SYMVERS
	done < <(nm -o $nvidia_mod | grep -E "$modules_pat")

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
