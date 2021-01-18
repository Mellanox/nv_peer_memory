obj-m += nv_peer_mem.o

PHONY += all clean install uninstall gen_nv_symvers
.PHONY: $(PHONY)

KVER := $(shell uname -r)
OFA_DIR ?= /usr/src/ofa_kernel
OFA_KERNEL ?= $(shell ( test -d $(OFA_DIR)/$(KVER) && echo $(OFA_DIR)/$(KVER) ) || ( test -d $(OFA_DIR)/default && echo $(OFA_DIR)/default ) || ( test -d /var/lib/dkms/mlnx-ofed-kernel/ && ls -d /var/lib/dkms/mlnx-ofed-kernel/*/build ) || ( echo $(OFA_DIR) ))

ifneq ($(shell test -d $(OFA_KERNEL) && echo "true" || echo "" ),)
$(info INFO: Building with MLNX_OFED from: $(OFA_KERNEL))
ccflags-y += -I$(OFA_KERNEL)/include/ -I$(OFA_KERNEL)/include/rdma
else
$(info INFO: Building with Inbox InfiniBand Stack)
$(warning "WARNING: Compilation might fail against Inbox InfiniBand Stack as it might lack needed support; in such cases you need to install MLNX_OFED package first.")
endif

PWD  := $(shell pwd)
MODULES_DIR := /lib/modules/$(KVER)
KDIR := $(MODULES_DIR)/build
MODULE_DESTDIR := $(MODULES_DIR)/extra/
DEPMOD := /sbin/depmod

MOD_NAME := nv_peer_mem
MOD_VERSION := $(shell awk '/^Version:/ {print $$2}' nvidia_peer_memory.spec)
DKMS_SRC_DIR := /usr/src/$(MOD_NAME)-$(MOD_VERSION)
SOURCE_FILES := Makefile compat_nv-p2p.h nv_peer_mem.c \
  create_nv.symvers.sh dkms.conf

# GCC earlier than 4.6.0 will build modules which require 'mcount',
# and this symbol will not be available in the kernel if the kernel was
# compiled with GCC 4.6.0 and above.
# therefore, to prevent unknown symbol issues we disable function tracing.
#
CC  = $(CROSS_COMPILE)gcc
CPP = $(CC) -E

CPP_MAJOR := $(shell $(CPP) -dumpversion 2>&1 | cut -d'.' -f1)
CPP_MINOR := $(shell $(CPP) -dumpversion 2>&1 | cut -d'.' -f2)
CPP_PATCH := $(shell $(CPP) -dumpversion 2>&1 | cut -d'.' -f3)
# Assumes that major, minor, and patch cannot exceed 999
CPP_VERS  := $(shell expr 0$(CPP_MAJOR) \* 1000000 + 0$(CPP_MINOR) \* 1000 + 0$(CPP_PATCH))
compile_h=$(shell /bin/ls -1 $(KDIR)/include/*/compile.h 2> /dev/null | head -1)
ifneq ($(compile_h),)
KERNEL_GCC_MAJOR := $(shell grep LINUX_COMPILER $(compile_h) | sed -r -e 's/.*gcc \S+ ([0-9\.\-]*) .*/\1/g' | cut -d'.' -f1)
KERNEL_GCC_MINOR := $(shell grep LINUX_COMPILER $(compile_h) | sed -r -e 's/.*gcc \S+ ([0-9\.\-]*) .*/\1/g' | cut -d'.' -f2)
KERNEL_GCC_PATCH := $(shell grep LINUX_COMPILER $(compile_h) | sed -r -e 's/.*gcc \S+ ([0-9\.\-]*) .*/\1/g' | cut -d'.' -f3)
KERNEL_GCC_VER  := $(shell expr 0$(KERNEL_GCC_MAJOR) \* 1000000 + 0$(KERNEL_GCC_MINOR) \* 1000 + 0$(KERNEL_GCC_PATCH))
ifneq ($(shell if [ $(CPP_VERS) -lt 4006000 ] && [ $(KERNEL_GCC_VER) -ge 4006000 ]; then \
                             echo "YES"; else echo ""; fi),)
$(info Warning: The kernel was compiled with GCC newer than 4.6.0, while the current GCC is older than 4.6.0, Disabling function tracing to prevent unknown symbol issues...)
override MAKE_PARAMS += CONFIG_FUNCTION_TRACER= CONFIG_HAVE_FENTRY=
endif
endif

#
# Get nv-p2p.h header file of the currently installed CUDA version.
# Try to get it based on available nvidia module version (just in case there are sources for couple of versions)
nv_version=$(shell /sbin/modinfo -F version -k $(KVER) nvidia 2>/dev/null)
nv_sources=$(shell /bin/ls -d /usr/src/nvidia-$(nv_version)/ 2>/dev/null)
ifneq ($(shell test -d "$(nv_sources)" && echo "true" || echo "" ),)
NV_P2P_H=$(shell /bin/ls -1 $(nv_sources)/nvidia/nv-p2p.h 2>/dev/null | tail -1)
else
NV_P2P_H=$(shell /bin/ls -1 /usr/src/nvidia-*/nvidia/nv-p2p.h 2>/dev/null | tail -1)
endif

all: gen_nv_symvers
ifneq ($(shell test -e "$(NV_P2P_H)" && echo "true" || echo "" ),)
	$(info Found $(NV_P2P_H))
	/bin/cp -f $(NV_P2P_H) $(PWD)/nv-p2p.h
else
	$(info Warning: nv-p2p.h was not found on the system, going to use compat_nv-p2p.h)
	/bin/cp -f $(PWD)/compat_nv-p2p.h $(PWD)/nv-p2p.h
endif
	echo -n "" > my.symvers
ifneq ($(shell test -d $(OFA_KERNEL) && echo "true" || echo "" ),)
	# get OFED symbols when building with MLNX_OFED
	/bin/cp -f $(OFA_KERNEL)/Module.symvers my.symvers
endif
	cat nv.symvers >> my.symvers
	make -C $(KDIR) $(MAKE_PARAMS) M=$(PWD) KBUILD_EXTRA_SYMBOLS="$(PWD)/my.symvers" modules

clean:
	make -C $(KDIR)  M=$(PWD) clean
	/bin/rm -f nv.symvers my.symvers nv-p2p.h

install:
	mkdir -p $(DESTDIR)/$(MODULE_DESTDIR);
	/bin/cp -f $(PWD)/nv_peer_mem.ko $(DESTDIR)/$(MODULE_DESTDIR);
	if [ ! -n "$(DESTDIR)" ]; then $(DEPMOD) -r -ae $(KVER);fi;

install-dkms: $(SOURCE_FILES)
	install -d $(DESTDIR)$(DKMS_SRC_DIR)
	cp -a $^ $(DESTDIR)$(DKMS_SRC_DIR)

install-utils:
	install -d $(DESTDIR)/etc/infiniband
	install -d $(DESTDIR)/etc/init.d
	install -d $(DESTDIR)/etc/init
	install -m 0644 nv_peer_mem.conf	$(DESTDIR)/etc/infiniband/nv_peer_mem.conf
	install -m 0755 nv_peer_mem		$(DESTDIR)/etc/init.d/nv_peer_mem
	install -m 0644 nv_peer_mem.upstart	$(DESTDIR)/etc/init/nv_peer_mem.conf

uninstall:
	/bin/rm -f $(DESTDIR)/$(MODULE_DESTDIR)/nv_peer_mem.ko
	if [ ! -n "$(DESTDIR)" ]; then $(DEPMOD) -r -ae $(KVER);fi;

gen_nv_symvers:
	$(PWD)/create_nv.symvers.sh $(KVER)
