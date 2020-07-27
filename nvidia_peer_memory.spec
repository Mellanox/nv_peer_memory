%define debug_package %{nil}
%{!?_release: %define _release 0}
%{!?KVERSION: %define KVERSION %(uname -r)}

%define MODPROBE %(if ( /sbin/modprobe -c | grep -q '^allow_unsupported_modules  *0'); then echo -n "/sbin/modprobe --allow-unsupported-modules"; else echo -n "/sbin/modprobe"; fi )

Summary: nvidia_peer_memory
Name: nvidia_peer_memory
Version: 1.1
Release: %{_release}
License: GPL
Group: System Environment/Libraries
Source: %{name}-%{version}.tar.gz
BuildRequires: gcc kernel-headers
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
URL: http://www.mellanox.com
Prefix: %{prefix}
Packager: <yishaih@mellanox.com>

%description

nvidia peer memory kernel module.

%prep
%setup -n %{name}-%{version}

%build
export KVER=%{KVERSION}
make KVER=$KVER all

%install

#install kernel module
export KVER=%{KVERSION}
make DESTDIR=$RPM_BUILD_ROOT KVER=$KVER install

# Copy configuration file
install -d $RPM_BUILD_ROOT/etc/infiniband
install -m 0644 $RPM_BUILD_DIR/%{name}-%{version}/nv_peer_mem.conf $RPM_BUILD_ROOT/etc/infiniband

# Install nv_peer_mem service script
install -d $RPM_BUILD_ROOT/etc/init.d
install -m 0755 $RPM_BUILD_DIR/%{name}-%{version}/nv_peer_mem $RPM_BUILD_ROOT/etc/init.d

%post
depmod -a
%{MODPROBE} -rq nv_peer_mem||:
%{MODPROBE} nv_peer_mem||:

if [[ -f /etc/redhat-release || -f /etc/rocks-release ]]; then
perl -i -ne 'if (m@^#!/bin/bash@) {
        print q@#!/bin/bash
#
# Bring up/down nv_peer_mem
#
# chkconfig: 2345 05 95
# description: Activates/Deactivates nv_peer_mem module to \
#              start at boot time.
#
### BEGIN INIT INFO
# Provides:       nv_peer_mem
# Required-Start: openibd
# Required-Stop:
### END INIT INFO
@;
                 } else {
                     print;
                 }' /etc/init.d/nv_peer_mem

        if ! ( /sbin/chkconfig --del nv_peer_mem > /dev/null 2>&1 ); then
                true
        fi
        if ! ( /sbin/chkconfig --add nv_peer_mem > /dev/null 2>&1 ); then
                true
        fi
fi

if [ -f /etc/SuSE-release ]; then
        perl -i -ne "if (m@^#!/bin/bash@) {
        print q@#!/bin/bash
### BEGIN INIT INFO
# Provides:       nv_peer_mem
# Required-Start: openibd
# Required-Stop:
# Default-Start:  2 3 5
# Default-Stop: 0 1 2 6
# Description:    Activates/Deactivates nv_peer_mem module to \
#                 start at boot time.
### END INIT INFO
@;
                 } else {
                     print;
                 }" /etc/init.d/nv_peer_mem

        if ! ( /sbin/insserv nv_peer_mem > /dev/null 2>&1 ); then
                true
        fi
fi

%preun
%{MODPROBE} -rq nv_peer_mem

if [[ -f /etc/redhat-release || -f /etc/rocks-release ]]; then
	if ! ( /sbin/chkconfig --del nv_peer_mem  > /dev/null 2>&1 ); then
		true
	fi
fi
if [ -f /etc/SuSE-release ]; then
	if ! ( /sbin/insserv -r nv_peer_mem > /dev/null 2>&1 ); then
		true
	fi
fi

%clean
# We may be in the directory that we're about to remove, so cd out of
# there before we remove it
cd /tmp
# Remove installed driver after rpm build finished
chmod -R o+w $RPM_BUILD_DIR/%{name}-%{version}
rm -rf $RPM_BUILD_DIR/%{name}-%{version}

test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT


%files
%defattr(-, root, root)
/lib/modules/%{KVERSION}/
/etc/init.d/nv_peer_mem
/etc/infiniband/nv_peer_mem.conf
