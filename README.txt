===============================================================================
NVIDIA peer memory client for Mellanox OFED                
README
      Aug 2016


===============================================================================
Table of Contents
===============================================================================
1. Overview   
2. Installation
3. Notes



===============================================================================
1. Overview
===============================================================================
General:
-----------
MLNX_OFED 2.1 introduced an API between IB CORE to peer memory clients,
(e.g. GPU cards) to provide access for the HCA to read/write peer memory for
data buffers. As a result it allows RDMA-based (over InfiniBand/RoCE)
application to use peer device computing power, and RDMA interconnect at the
same time w/o copying the data between the P2P devices

GPUDirect RDMA is an example of.

This README describes the required steps to install and work over
Mellanox OFED with NVIDIA peer client.

Content:
-----------
This tarball contains 3 files:
1) This README.
2) nvidia-peer-memory_1.0.orig.tar.gz for Ubuntu.
3) nvidia_peer_memory-1.0-1.src.rpm for other operating systems.

===============================================================================
Installation
===============================================================================

Prerequisites:
1) NVIDIA driver is installed and up.
2) MLNX_OFED 2.1 is installed and up.

For the required NVIDIA driver and other relevant details in that area
please check with NVIDIA support.


To install run (excluding ubuntu):
                rpmbuild --rebuild <path to srpm>.
                rpm -ivh <path to generated binary rpm file.> [On SLES add --nodeps].
				

To install on Ubuntu run:
          copy tarball to temp directory.
          tar xzf <tarball>
          cd <extracted directory>
          dpkg-buildpackage -us -uc
          dpkg -i <path to generated deb files.>

		  (e.g. dpkg -i nvidia-peer-memory_1.0-1_all.deb 
		       dpkg -i nvidia-peer-memory-dkms_1.0-1_all.deb)

After successful installation:
1)	nv_peer_mem.ko is installed
2)	service file /etc/init.d/nv_peer_mem to be used for start/stop/status
	for that kernel module was added.
3)	/etc/infiniband/nv_peer_mem.conf to control whether kernel module will be loaded on boot
	(default is YES) was added.
			   

===============================================================================
Notes
===============================================================================

To achieve good performance both the NIC and the GPU must physically sit on same slot,
use lspci -tv to make sure that this is the case.


