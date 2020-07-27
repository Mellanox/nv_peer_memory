# Mellanox OFED GPUDirect RDMA

The latest advancement in GPU-GPU communications is GPUDirect RDMA. This new technology provides a direct P2P (Peer-to-Peer) data path between the GPU Memory directly to/from the Mellanox HCA devices. This provides a significant decrease in GPU-GPU communication latency and completely offloads the CPU, removing it from all GPU-GPU communications across the network.

http://www.mellanox.com/page/products_dyn?product_family=116

===============================================================================
1. Overview
===============================================================================

General:
-----------
MLNX_OFED 2.1 introduces an API between IB CORE to peer memory clients, such as NVIDIA Kepler class GPU's, (e.g. GPU cards), also known as GPUDirect RDMA.  It provides access for the HCA to read/write peer memory data buffers, as a result it allows RDMA-based applications to use the peer device computing power with the RDMA interconnect without the need for copying data to host memory.

This capability is supported with Mellanox ConnectX-3 VPI or Connect-IB InfiniBand adapters.  It will also work seemlessly using RoCE technology with the Mellanox ConnectX-3 VPI adapters.

This README describes the required steps to completing the installation for the NVIDIA peer memory client with Mellanox OFED.


===============================================================================
Installation
===============================================================================

Pre-requisites:
1) NVIDIA compatible driver is installed and up.
2) MLNX_OFED 2.1 is installed and up.

For the required NVIDIA driver and other relevant details in that area
please check with NVIDIA support.

To build source packages (src.rpm for RPM based OS and tarball for DEB based OS), use the build_module.sh script.


Example:

    $ ./build_module.sh

    Building source rpm for nvidia_peer_memory...
    Building debian tarball for nvidia-peer-memory...

    Built: /tmp/nvidia_peer_memory-1.1-0.src.rpm
    Built: /tmp/nvidia-peer-memory_1.0.orig.tar.gz

To install on RPM based OS:

    # rpmbuild --rebuild /tmp/nvidia_peer_memory-1.1-0.src.rpm
    # rpm -ivh <path to generated binary rpm file>

To install on DEB based OS:

    # cd /tmp
    # tar xzf /tmp/nvidia-peer-memory_1.0.orig.tar.gz
    # cd nvidia-peer-memory-1.0
    # dpkg-buildpackage -us -uc
    # dpkg -i <path to generated deb files>

To install run (excluding ubuntu):

    rpmbuild --rebuild <path to srpm>.
    rpm -ivh <path to generated binary rpm file.> [On SLES add --nodeps].

To install on Ubuntu run:

    dpkg-buildpackage -us -uc
    dpkg -i <path to generated deb files.>

    (e.g. dpkg -i nvidia-peer-memory_1.1-0_all.deb
          dpkg -i nvidia-peer-memory-dkms_1.1-0_all.deb)

After successful installation:
1)	nv_peer_mem.ko is installed
2)	service file /etc/init.d/nv_peer_mem to be used for start/stop/status
	for that kernel module was added.
3)	/etc/infiniband/nv_peer_mem.conf to control whether kernel module will be loaded on boot
	(default is YES) was added.

===============================================================================
Notes
===============================================================================

To achieve good performance both the NIC and the GPU must physically sit on same i/o root complex,
use lspci -tv to make sure that this is the case.
