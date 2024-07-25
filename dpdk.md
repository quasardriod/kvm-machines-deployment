# DPDK

- [System Requirements](https://doc.dpdk.org/guides/linux_gsg/sys_reqs.html)
- [DPDK Files](#dpdk-files)
- [Hugepages](#hugepages)
- [Linux Drivers](#linux-drivers)
  - [VFIO](#vfio)
    - [VFIO no-IOMMU Mode](#vfio-no-iommu-mode)
- [Interface Binding](#interface-binding)

## DPDK Files
**Before Compiling DPDK**
```
[root@localhost dpdk-24.03]# ls -l
total 112
-rw-rw-r--.  1 root root     5 Mar 28 19:26 ABI_VERSION
drwxrwxr-x. 23 root root  4096 Mar 28 19:26 app
drwxrwxr-x.  5 root root  4096 Mar 28 19:26 buildtools
drwxrwxr-x.  7 root root   108 Mar 28 19:26 config
drwxrwxr-x.  3 root root  4096 Mar 28 19:26 devtools
drwxrwxr-x.  5 root root    62 Mar 28 19:26 doc
drwxrwxr-x. 16 root root  4096 Mar 28 19:26 drivers
drwxrwxr-x.  5 root root   165 Mar 28 19:26 dts
drwxrwxr-x. 49 root root  4096 Mar 28 19:26 examples
drwxrwxr-x.  3 root root    40 Mar 28 19:26 kernel
drwxrwxr-x. 59 root root  4096 Mar 28 19:26 lib
drwxrwxr-x.  2 root root   159 Mar 28 19:26 license
-rw-rw-r--.  1 root root 50702 Mar 28 19:26 MAINTAINERS
-rw-rw-r--.  1 root root   219 Mar 28 19:26 Makefile
-rw-rw-r--.  1 root root  5364 Mar 28 19:26 meson.build
-rw-rw-r--.  1 root root  4641 Mar 28 19:26 meson_options.txt
-rw-rw-r--.  1 root root   510 Mar 28 19:26 README
drwxrwxr-x.  2 root root  4096 Mar 28 19:26 usertools
-rw-rw-r--.  1 root root     8 Mar 28 19:26 VERSION
```

**After Compiling DPDK**
```
[root@dpdk01 dpdk-24.03]# ls -l
total 116
-rw-rw-r--.  1 root root     5 Mar 28 19:26 ABI_VERSION
drwxrwxr-x. 23 root root  4096 Mar 28 19:26 app
drwxr-xr-x. 15 root root  4096 Jul 25 10:12 build
drwxrwxr-x.  6 root root  4096 Jul 25 10:13 buildtools
drwxrwxr-x.  7 root root   108 Mar 28 19:26 config
drwxrwxr-x.  3 root root  4096 Mar 28 19:26 devtools
drwxrwxr-x.  5 root root    62 Mar 28 19:26 doc
drwxrwxr-x. 16 root root  4096 Mar 28 19:26 drivers
drwxrwxr-x.  5 root root   165 Mar 28 19:26 dts
drwxrwxr-x. 49 root root  4096 Mar 28 19:26 examples
drwxrwxr-x.  3 root root    40 Mar 28 19:26 kernel
drwxrwxr-x. 59 root root  4096 Mar 28 19:26 lib
drwxrwxr-x.  2 root root   159 Mar 28 19:26 license
-rw-rw-r--.  1 root root 50702 Mar 28 19:26 MAINTAINERS
-rw-rw-r--.  1 root root   219 Mar 28 19:26 Makefile
-rw-rw-r--.  1 root root  5364 Mar 28 19:26 meson.build
-rw-rw-r--.  1 root root  4641 Mar 28 19:26 meson_options.txt
-rw-rw-r--.  1 root root   510 Mar 28 19:26 README
drwxrwxr-x.  2 root root  4096 Mar 28 19:26 usertools
-rw-rw-r--.  1 root root     8 Mar 28 19:26 VERSION
```
## Hugepages

Hugepages being set using `dpdk.yml` playbook. DPDK also provides `dpdk-hugepages.py` utility to set hugepages on system.
```bash
./usertools/dpdk-hugepages.py
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