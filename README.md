- [Introduction](#introduction)
- [QEMU Connection](#qemu-connection)
  - [*Set QEMU for local KVM host*](#set-qemu-for-local-kvm-host)
  - [*Set QEMU to connect to a remote KVM host*](#set-qemu-to-connect-to-a-remote-kvm-host)
- [Tool Kit](#tool-kit)
- [View KVM Host Capabilities](#view-kvm-host-capabilities)
- [Prepare KVM host](#prepare-kvm-host)
- [Build and Management of KVM guests](#build-and-management-of-kvm-guests)
- [Lifecycle Management of Guest Machines](#lifecycle-management-of-guest-machines)

## Introduction
- [What is KVM](https://www.redhat.com/en/topics/virtualization/what-is-KVM)
---

## QEMU Connection
Review [qumu-connect](./docs/qemu-connect.md) for detailed information on `virsh` connection options, to manage guest VMs on remote KVM host. Review [constant.sh](./scripts/constant.sh) for `virsh` connection configuration code.

### *Set QEMU for local KVM host*
*By default* [run.sh](./run.sh) will connect to local KVM host using:
`export LIBVIRT_DEFAULT_URI=qemu:///system`

`virsh` command performs all operations on localhost as `root` user by using `sudo`. Without `sudo`, `qemu:///system` will prompt for password.
  - If you are not running `run.sh` as root, ensure current user has sudo access with `nopasswd`.

### *Set QEMU to connect to a remote KVM host*
- Configure password less authentication for remote machine `root` user.
- Export `LIBVIRT_DEFAULT_URI` param as below:
```bash
export LIBVIRT_DEFAULT_URI=qemu+ssh://root@[hostname/IP]/system
```
---
## Tool Kit
`setup.sh` has been provided for KVM host and guest deployment and management.
```bash
./setup.sh -h
```
---

## View KVM Host Capabilities
Run below command to list supported capabilities on target KVM host.

```bash
./setup.sh -i
```
---

## Prepare KVM host
Run below command to prepare target KVM host for capabilities listed in `setup.sh -i`
```bash
./setup.sh -p
```
---

## Build and Management of KVM guests
Based on supported images & networks, create a yaml file for machines to be build for defined properties. Review [job-inputs.yml](./job-inputs.yml) for more information.

User will be prompted to provide input on following actions after the machines are created:
- Update OS
- Lifecycle Management of new built machines
  - Create snapshot

```bash
./setup.sh -m [job-inputs.yml]
```
---

## Lifecycle Management of Guest Machines
Run below command for lifecycle management options of the guest machines.

```bash
./setup.sh -l [job-inputs.yml]
```
---