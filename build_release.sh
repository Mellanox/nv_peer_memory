#!/bin/bash
# vim: ts=4 sw=4 expandtab
#
# Author: Alaa Hleihel <alaa@mellanox.com>
#

GIT_URL=${GIT_URL:-"https://github.com/Mellanox/nv_peer_memory.git"}

GIT_BRANCH=${GIT_BRANCH:-"master"}
ex()
{
    if ! eval "$@"; then
        echo "Failed to execute: $@" >&2
        exit 1
    fi
}

tmpdir=`mktemp -d /tmp/nv.XXXXXX`
if [ ! -d "$tmpdir" ]; then
    echo "Failed to create a temp directory!" >&2
    exit 1
fi
echo "Working in $tmpdir ..."
cd $tmpdir

#clone
echo "Cloning from $GIT_URL ..."
ex git clone $GIT_URL >/dev/null
dirname=`ls -1`
cd $dirname
echo "Checking out branch: $GIT_BRANCH ..."
ex git checkout $GIT_BRANCH >/dev/null
VERSION=`grep Version: *.spec | cut -d : -f 2 | sed -e 's@\s@@g'`
RELEASE=`grep "define _release" *.spec | cut -d" " -f"4"| sed -r -e 's/}//'`
if [ "X$VERSION" == "X" ] || [ "X$RELEASE" == "X" ]; then
    echo "Failed to get version numbers!" >&2
    exit 1
fi

cd $tmpdir
ex mv $dirname nvidia_peer_memory-$VERSION
ex tar czf nvidia_peer_memory-$VERSION.tar.gz nvidia_peer_memory-$VERSION --exclude=.* --exclude=build_release.sh

echo
echo "Building source rpm for nvidia_peer_memory..."
mkdir -p $tmpdir/topdir/{SRPMS,RPMS,SPECS,BUILD}
ex "rpmbuild -ts --nodeps --define '_topdir $tmpdir/topdir' --define 'dist %{nil}' --define '_source_filedigest_algorithm md5' --define '_binary_filedigest_algorithm md5' nvidia_peer_memory-$VERSION.tar.gz >/dev/null"
srpm=`ls -1 $tmpdir/topdir/SRPMS/`
mv $tmpdir/topdir/SRPMS/$srpm /tmp

echo "Building debian tarball for nvidia-peer-memory..."
ex mv nvidia_peer_memory-$VERSION nvidia-peer-memory-$VERSION
# update version in changelog
sed -i -r "0,/^(.*) \(([a-zA-Z0-9.-]+)\) (.*)/s//\1 \(${VERSION}-${RELEASE}\) \3/" nvidia-peer-memory-${VERSION}/debian/changelog
ex tar czf nvidia-peer-memory_$VERSION.orig.tar.gz nvidia-peer-memory-$VERSION --exclude=.* --exclude=build_release.sh
ex mv nvidia-peer-memory_$VERSION.orig.tar.gz /tmp

/bin/rm -rf $tmpdir

echo ""
echo Built: /tmp/$srpm
echo Built: /tmp/nvidia-peer-memory_$VERSION.orig.tar.gz
echo ""
echo "To install run on RPM based OS:"
echo "    # rpmbuild --rebuild /tmp/$srpm"
echo "    # rpm -ivh <path to generated binary rpm file>" 
echo ""
echo "To install on DEB based OS:"
echo "    # cd /tmp"
echo "    # tar xzf /tmp/nvidia-peer-memory_$VERSION.orig.tar.gz"
echo "    # cd nvidia-peer-memory-$VERSION"
echo "    # dpkg-buildpackage -us -uc"
echo "    # dpkg -i <path to generated deb files>"
echo ""
