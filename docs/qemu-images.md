- [Create and Resize a QCOW2 Image](#create-and-resize-a-qcow2-image)
- [Prerequisites](#prerequisites)
- [Steps to Create and Resize a QCOW2 Image](#steps-to-create-and-resize-a-qcow2-image)
    - [Step 1: Download the Cloud Image](#step-1-download-the-cloud-image)
    - [Step 2: Convert/Copy and Resize the QCOW2 Image](#step-2-convertcopy-and-resize-the-qcow2-image)
    - [Step 3: Verify the New Disk Size](#step-3-verify-the-new-disk-size)
    - [Step 4: Expand the Filesystem Inside the Image (Crucial!)](#step-4-expand-the-filesystem-inside-the-image-crucial)
      - [Alternative for `virt-resize` if you already resized with `qemu-img resize`:](#alternative-for-virt-resize-if-you-already-resized-with-qemu-img-resize)
      - [Simpler approach combining `qemu-img create` and `virt-resize`:](#simpler-approach-combining-qemu-img-create-and-virt-resize)
    - [Step 5: Verify the Filesystem Expansion (Optional, but Recommended)](#step-5-verify-the-filesystem-expansion-optional-but-recommended)
      - [Alternative: Relying on Cloud-Init for Resizing](#alternative-relying-on-cloud-init-for-resizing)

# Create and Resize a QCOW2 Image
Creating a QCOW2 image from a cloud image and increasing its size is a common task when preparing virtual machines. QCOW2 (QEMU Copy-On-Write) is a flexible disk image format that supports features like snapshots and smaller file sizes for sparse images. Cloud images are typically minimal, pre-configured OS images designed for quick deployment in cloud environments, and often come with a small default disk size.

This guide will walk you through the process of taking a cloud image, converting it to QCOW2 (if it's not already in that format), increasing its virtual disk size, and importantly, expanding the filesystem within the image so the operating system can actually utilize the new space.

# Prerequisites
Before you begin, ensure you have the following tools installed on your Linux system:
1. `qemu-img`: For converting and resizing disk images.
    - On Debian/Ubuntu: `sudo apt-get install qemu-utils`
    - On RHEL/CentOS/Fedora: `sudo yum install qemu-img or sudo dnf install qemu-img`

2. `libguestfs-tools`: For manipulating the filesystem inside the disk image without booting it. This includes `virt-resize` and `virt-customize`.
    - On Debian/Ubuntu: `sudo apt-get install libguestfs-tools`
    - On RHEL/CentOS/Fedora: `sudo yum install libguestfs-tools` or `sudo dnf install libguestfs-tools`

# Steps to Create and Resize a QCOW2 Image
Let's assume you want to use an Ubuntu cloud image and resize it to 20GB.

### Step 1: Download the Cloud Image

First, download the desired cloud image. For example, the latest Ubuntu 22.04 LTS (Jammy Jellyfish) cloud image:

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img 
```
*Note: Cloud images often come in QCOW2 format already, but the process remains similar for other formats like raw, as qemu-img convert handles the format change.*

### Step 2: Convert/Copy and Resize the QCOW2 Image

You can use `qemu-img convert` to create a new QCOW2 image from the downloaded cloud image and simultaneously set its new maximum size.

```bash
qemu-img convert -f qcow2 -O qcow2 jammy-server-cloudimg-amd64.img resized_ubuntu.qcow2
qemu-img resize resized_ubuntu.qcow2 20G 
```
* `-f qcow2`: Specifies the format of the input file (change if your downloaded image is a different format).
* -`O qcow2`: Specifies the output format (QCOW2).
* `jammy-server-cloudimg-amd64.img`: Your downloaded cloud image.
* `resized_ubuntu.qcow2`: The name of your new, resized QCOW2 image.
* `20G`: The desired new size (e.g., 20 Gigabytes). You can use M for Megabytes, G for Gigabytes, T for Terabytes.

**Important:** The qemu-img resize command only changes the virtual size of the disk image. It does not automatically expand the partitions or filesystems inside the image. This is a crucial distinction.

### Step 3: Verify the New Disk Size
You can verify the virtual size of your new QCOW2 image:

```bash
qemu-img info resized_ubuntu.qcow2 
```

Look for the `virtual size` field in the output. It should now show `20.0 GiB` (or your specified size).

### Step 4: Expand the Filesystem Inside the Image (Crucial!)

This is the most important step to make the newly added space usable by the operating system. We'll use `virt-resize` from `libguestfs-tools`.

`virt-resize` works by copying the original image to a new, larger image while expanding the partitions and filesystems.

```bash
virt-resize --expand /dev/sda1 jammy-server-cloudimg-amd64.img final_ubuntu.qcow2 
```

* `--expand /dev/sda1`: This tells virt-resize to expand the partition /dev/sda1 to fill the available space on the disk. Most cloud images have their root filesystem on /dev/sda1. You might need to check your specific image's partition layout if it's different (e.g., using `virt-filesystems -a jammy-server-cloudimg-amd64.img`).
* `jammy-server-cloudimg-amd64.img`: The original cloud image (or the `resized_ubuntu.qcow2` if you already resized it with `qemu-img resize` and want to expand its internal partitions).
* `final_ubuntu.qcow2`: The new output image with the expanded filesystem.


#### Alternative for `virt-resize` if you already resized with `qemu-img resize`:

If you already ran `qemu-img resize` in Step 2, you can use `virt-resize` like this:

```
# First, create a temporary empty file for virt-resize to output to 
# The size of this file should be at least the target size (e.g., 20G) 

truncate -s 20G temp_output.qcow2

# Now use virt-resize to copy from the resized_ubuntu.qcow2 to the temp_output.qcow2 
# and expand the filesystem
virt-resize --expand /dev/sda1 resized_ubuntu.qcow2 temp_output.qcow2

# Finally, convert the temporary file to a proper QCOW2 if it's not already,
# or just rename it.
mv temp_output.qcow2 final_ubuntu.qcow2 
```

This method is a bit more convoluted because virt-resize typically expects to resize from a source image to a larger destination image, rather than in-place. The --expand flag works best when the destination disk is larger.

#### Simpler approach combining `qemu-img create` and `virt-resize`:

A cleaner way to achieve this, especially if you're starting from a raw image or want to ensure the target size is set before resizing the filesystem:

1. **Create a new, empty QCOW2 image of the desired final size:**
```bash
qemu-img create -f qcow2 final_ubuntu.qcow2 20G 
```

2. **Use virt-resize to copy the original cloud image into the new, larger QCOW2 image and expand the filesystem:**
```bash
virt-resize --expand /dev/sda1 jammy-server-cloudimg-amd64.img final_ubuntu.qcow2 
```

This command will copy the contents of jammy-server-cloudimg-amd64.img into final_ubuntu.qcow2, expanding /dev/sda1 to fill the 20GB space.

### Step 5: Verify the Filesystem Expansion (Optional, but Recommended)

You can use `virt-filesystems` to inspect the partitions and filesystems within your final_ubuntu.qcow2 image:

```bash
virt-filesystems --long -h -a final_ubuntu.qcow2 
```

Look for the size of `/dev/sda1` and its corresponding filesystem. It should now reflect the expanded size (e.g., close to 20GB).

#### Alternative: Relying on Cloud-Init for Resizing

Many cloud images are configured to use `cloud-init`, a package that handles initialization tasks on first boot. One of its common functionalities is to automatically resize the root filesystem to fill the available disk space.

If you simply create a larger QCOW2 image (using `qemu-img resize` as in Step 2) and then boot the VM with that image, cloud-init might automatically expand the filesystem for you on the first boot.

**Steps for Cloud-Init based resizing:**

1. **Download and resize the QCOW2 image:**

```bash
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img qemu-img resize jammy-server-cloudimg-amd64.img 20G 
```
*Note: Here, we're resizing the original image directly, assuming it's already QCOW2. If not, add qemu-img convert first.*

2. **Boot the VM:** When you boot a VM using `jammy-server-cloudimg-amd64.img` (now 20GB), `cloud-init` should detect the larger disk and expand the root filesystem.

**When to use `virt-resize` vs. Cloud-Init:**

* `virt-resize` **(recommended for reliability)**: Use this if you need to guarantee the filesystem is expanded before the VM boots, or if you're dealing with an image that doesn't have `cloud-init` or its `cloud-init` configuration doesn't handle resizing. It's a more robust and explicit way to manage disk space.

* **Cloud-Init:** Convenient if you trust the cloud image's cloud-init configuration to handle resizing on first boot. This is often sufficient for standard cloud deployments.

**Conclusion**

You now have a QCOW2 image with a larger virtual disk size and an expanded filesystem, ready for use in your virtualization environment (e.g., QEMU, KVM, Proxmox). Remember that resizing the disk and expanding the filesystem are two distinct but equally important steps to fully utilize the new storage space.