# DPDK

- [System Requirements](https://doc.dpdk.org/guides/linux_gsg/sys_reqs.html)
- [Hugepages](#hugepages)
- [DPDK Build](#dpdk-files)
- [Linux Drivers](#linux-drivers)
  - [VFIO](#vfio)
    - [VFIO no-IOMMU Mode](#vfio-no-iommu-mode)
- [Interface Binding](#interface-binding)

## Hugepages

Hugepages being set using `dpdk.yml` playbook. DPDK also provides `dpdk-hugepages.py` utility to set hugepages on system.
```bash
./usertools/dpdk-hugepages.py
```

## DPDK Build
> TODO: Write a script for below steps

```bash
# uname -a
Linux dpdk02 5.14.0-427.13.1.el9_4.x86_64 #1 SMP PREEMPT_DYNAMIC Wed May 1 19:11:28 UTC 2024 x86_64 x86_64 x86_64 GNU/Linux

# ls -l dpdk-24.03.tar.xz 
-rw-r--r--. 1 root root 16507004 Jul 25 10:09 dpdk-24.03.tar.xz

# tar -xf dpdk-24.03.tar.xz

# cd dpdk-24.03

# meson build

# ninja -C build
```

## Linux Drivers
**Official Documentation:** https://doc.dpdk.org/guides/linux_gsg/linux_drivers.html#

- VFIO
- UIO
- [vfio vs uio](https://edc.intel.com/content/www/us/en/design/products/ethernet/config-guide-e810-dpdk/linux-drivers/#:~:text=VFIO%20driver%20is%20a%20robust,user%20space%2C%20and%20register%20interrupts.)

### VFIO
https://doc.dpdk.org/guides/linux_gsg/linux_drivers.html#vfio-noiommu

```
modprobe vfio-pci
```

#### VFIO no-IOMMU Mode

- Usually in case of VMs machine may not have IOMMU enabled. Below example of machine with no-IOMMU.
```
# ls -l /sys/class/iommu/
total 0
```

- Enable vfio with no-IOMMU
```
modprobe vfio enable_unsafe_noiommu_mode=1
```

## Interface Binding
**Pre-requisites:**
-  Interface that need to be managed by DPDK should not be active in kernel routing table
-  

- Below util shows current mapping, both interfaces are managed by kernel
  - Missing `Active` status indicates interface is not in routing table
```
[root@dpdk01 dpdk-24.03]# ./usertools/dpdk-devbind.py --status

Network devices using kernel driver
===================================
0000:01:00.0 'Virtio 1.0 network device 1041' if=eth0 drv=virtio-pci unused=vfio-pci *Active*
0000:02:00.0 'Virtio 1.0 network device 1041' if=eth1 drv=virtio-pci unused=vfio-pci 

No 'Baseband' devices detected
==============================

No 'Crypto' devices detected
============================

No 'DMA' devices detected
=========================

No 'Eventdev' devices detected
==============================

No 'Mempool' devices detected
=============================

No 'Compress' devices detected
==============================

Misc (rawdev) devices using kernel driver
=========================================
0000:05:00.0 'Virtio 1.0 block device 1042' drv=virtio-pci unused=vfio-pci 

No 'Regex' devices detected
===========================

No 'ML' devices detected
========================
```

- Take eth1 in dpdk control
  - dpdk managed interfaces won't be visible in `ip` command

```
# ./usertools/dpdk-devbind.py --bind=vfio-pci eth1

# ./usertools/dpdk-devbind.py --status

Network devices using DPDK-compatible driver
============================================
0000:02:00.0 'Virtio 1.0 network device 1041' drv=vfio-pci unused=

Network devices using kernel driver
===================================
0000:01:00.0 'Virtio 1.0 network device 1041' if=eth0 drv=virtio-pci unused=vfio-pci *Active*

No 'Baseband' devices detected
==============================

No 'Crypto' devices detected
============================

No 'DMA' devices detected
=========================

No 'Eventdev' devices detected
==============================

No 'Mempool' devices detected
=============================

No 'Compress' devices detected
==============================

Misc (rawdev) devices using kernel driver
=========================================
0000:05:00.0 'Virtio 1.0 block device 1042' drv=virtio-pci unused=vfio-pci 

No 'Regex' devices detected
===========================

No 'ML' devices detected
========================

```