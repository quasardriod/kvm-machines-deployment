- [Introduction](#introduction)
- [Requirements](#requirements)
- [QEMU Connection](#qemu-connection)
  - [*Set QEMU for local KVM host*](#set-qemu-for-local-kvm-host)
  - [*Set QEMU to connect to a remote KVM host*](#set-qemu-to-connect-to-a-remote-kvm-host)
- [Create Guest Machines Input File](#create-guest-machines-input-file)
- [Tool Kit](#tool-kit)
- [View KVM Host Capabilities](#view-kvm-host-capabilities)
- [Prepare KVM host](#prepare-kvm-host)
- [Build and Management of KVM guests](#build-and-management-of-kvm-guests)
- [Lifecycle Management of Guest Machines](#lifecycle-management-of-guest-machines)
- [Create Additional KVM Networks](#create-additional-kvm-networks)

## Introduction
[What is KVM](https://www.redhat.com/en/topics/virtualization/what-is-KVM)

---

## Requirements
- Ansible Core v2.17+
- Python 3.12

**Ansible Collections:**
- community.general
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

## Create Guest Machines Input File
In order to create KVM guest machines, please create an yaml file in [guest-machines-input.yml](./guest-machines-input.yml) format.

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

## Create Additional KVM Networks
User may need additional network to isolate the traffic between guest machines for specific deployments, example: `openstack, kubernetes`.

In [custom-resources](./custom-resources/README.md) directory additional network resources are managed.
Create `yaml` file in this directory to create additional networks.

**NOTE:** 
- Network `yaml` file must follow below format.
- `uuid` will be generated during network creation.
- Ensure top level variable set to `additional_kvm_networks`.

```yaml
additional_kvm_networks:
- name: dataplane
  forward_mode: nat
  gw: 192.168.64.1
  netmask: 255.255.255.0
  range:
    start: 192.168.64.2
    end: 192.168.64.254
```

---