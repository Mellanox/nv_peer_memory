#!/bin/bash
set -e
SCRIPTPATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
force=${force:-0}


echo "Building source packages..."
VERSION=`grep Version: *.spec | cut -d : -f 2 | sed -e 's@\s@@g'`
RELEASE=`grep "define _release" *.spec | cut -d" " -f"4"| sed -r -e 's/}//'`


rm -rf release
mkdir release
cd release
mkdir nvidia_peer_memory-$VERSION-$RELEASE

cp ../README.txt nvidia_peer_memory-$VERSION-$RELEASE/

for file in $($SCRIPTPATH/gen_nvidia_plugin_srpm.sh 2>/dev/null | grep Built: | sed -r -e 's/.*\s//')
do
	mv $file nvidia_peer_memory-$VERSION-$RELEASE/
done

echo building package tarball...
tar czf nvidia_peer_memory-$VERSION-$RELEASE.tar.gz nvidia_peer_memory-$VERSION-$RELEASE
rm -rf nvidia_peer_memory-$VERSION-$RELEASE

if [ $force -eq 0 ] && [ -f "/mswg/release/nvidia_peer_memory/nvidia_peer_memory-$VERSION-$RELEASE.tar.gz" ]; then
	echo "Error: /mswg/release/nvidia_peer_memory/nvidia_peer_memory-$VERSION-$RELEASE.tar.gz already exists!"
	exit 1
fi
cp nvidia_peer_memory-$VERSION-$RELEASE.tar.gz /mswg/release/nvidia_peer_memory/
