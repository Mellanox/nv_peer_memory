obj-m += nv_peer_mem.o

PHONY += all clean install uninstall gen_nv_symvers
.PHONY: $(PHONY)

KVER := $(shell uname -r)
OFA_DIR ?= /usr/src/ofa_kernel
OFA_KERNEL ?= $(shell ( test -d $(OFA_DIR)/$(KVER) && echo $(OFA_DIR)/$(KVER) ) || ( test -d $(OFA_DIR)/default && echo $(OFA_DIR)/default ) || ( test -d /var/lib/dkms/mlnx-ofed-kernel/ && ls -d /var/lib/dkms/mlnx-ofed-kernel/*/build ) || ( echo $(OFA_DIR) ))

ccflags-y += -I$(OFA_KERNEL)/include/ -I$(OFA_KERNEL)/include/rdma
PWD  := $(shell pwd)
MODULES_DIR := /lib/modules/$(KVER)
KDIR := $(MODULES_DIR)/build
MODULE_DESTDIR := $(MODULES_DIR)/extra/
DEPMOD := /sbin/depmod

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
KERNEL_GCC_MAJOR := $(shell grep LINUX_COMPILER $(compile_h) | sed -r -e 's/.*gcc version ([0-9\.\-]*) .*/\1/g' | cut -d'.' -f1)
KERNEL_GCC_MINOR := $(shell grep LINUX_COMPILER $(compile_h) | sed -r -e 's/.*gcc version ([0-9\.\-]*) .*/\1/g' | cut -d'.' -f2)
KERNEL_GCC_PATCH := $(shell grep LINUX_COMPILER $(compile_h) | sed -r -e 's/.*gcc version ([0-9\.\-]*) .*/\1/g' | cut -d'.' -f3)
KERNEL_GCC_VER  := $(shell expr 0$(KERNEL_GCC_MAJOR) \* 1000000 + 0$(KERNEL_GCC_MINOR) \* 1000 + 0$(KERNEL_GCC_PATCH))
ifneq ($(shell if [ $(CPP_VERS) -lt 4006000 ] && [ $(KERNEL_GCC_VER) -ge 4006000 ]; then \
                             echo "YES"; else echo ""; fi),)
$(info Warning: The kernel was compiled with GCC newer than 4.6.0, while the current GCC is older than 4.6.0, Disabling function tracing to prevent unknown symbol issues...)
override MAKE_PARAMS += CONFIG_FUNCTION_TRACER= CONFIG_HAVE_FENTRY=
endif
endif

#
# Get nv-p2p.h header file of the currently installed CUDA version.
NV_P2P_H=$(shell /bin/ls -1 /usr/src/nvidia-*/nvidia/nv-p2p.h 2>/dev/null | tail -1)

all: gen_nv_symvers
ifneq ($(shell test -e "$(NV_P2P_H)" && echo "true" || echo "" ),)
	$(info Found $(NV_P2P_H))
	/bin/cp -f $(NV_P2P_H) $(PWD)/nv-p2p.h
else
	$(info Warning: nv-p2p.h was not found on the system, going to use compat_nv-p2p.h)
	/bin/cp -f $(PWD)/compat_nv-p2p.h $(PWD)/nv-p2p.h
endif
	cp -rf $(OFA_KERNEL)/Module.symvers .
	cat nv.symvers >> Module.symvers
	make -C $(KDIR) $(MAKE_PARAMS) M=$(PWD) modules

clean:
	make -C $(KDIR)  M=$(PWD) clean
	/bin/rm -f nv.symvers nv-p2p.h

install:
	mkdir -p $(DESTDIR)/$(MODULE_DESTDIR);
	cp -f $(PWD)/nv_peer_mem.ko $(DESTDIR)/$(MODULE_DESTDIR);
	if [ ! -n "$(DESTDIR)" ]; then $(DEPMOD) -r -ae $(KVER);fi;

uninstall:
	/bin/rm -f $(DESTDIR)/$(MODULE_DESTDIR)/nv_peer_mem.ko
	if [ ! -n "$(DESTDIR)" ]; then $(DEPMOD) -r -ae $(KVER);fi;

gen_nv_symvers:
	$(PWD)/create_nv.symvers.sh $(KVER)
