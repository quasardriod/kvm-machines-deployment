- [Introduction](#introduction)
- [Requirements](#requirements)
- [QEMU Connection and KVM Host Inventory](#qemu-connection-and-kvm-host-inventory)
  - [*Set QEMU for local KVM host*](#set-qemu-for-local-kvm-host)
  - [*Set QEMU to connect to a remote KVM host*](#set-qemu-to-connect-to-a-remote-kvm-host)
  - [Prepare KVM Host Inventory](#prepare-kvm-host-inventory)
- [Create Guest Machines Input File](#create-guest-machines-input-file)
- [Tool Kit](#tool-kit)
- [View KVM Host Capabilities](#view-kvm-host-capabilities)
- [Prepare KVM host](#prepare-kvm-host)
- [Build and Management of KVM Guest Machines](#build-and-management-of-kvm-guest-machines)
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

## QEMU Connection and KVM Host Inventory
Review [qumu-connection](./docs/qemu-connection.md) for detailed information on `virsh` connection options, to manage guest VMs on remote KVM host. Review [constant.sh](./scripts/constant.sh) for `virsh` connection configuration code.

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

### Prepare KVM Host Inventory
Prepare Inventory of KVM hosts. KVM machines inventory mush be stored in following files.
- **inventory/kvm-local.yml**: Running playbooks on local KVM host.
- **inventory/kvm-remote.yml**: To run playbooks on remove KVM host.

> NOTE: Based on exported `LIBVIRT_DEFAULT_URI` environment variable, inventory will be automatically seleted from the above list.

**For Local KVM host**
```bash
$cat inventory/kvm-local.yml 
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_user: <current user>
  vars:
    ansible_python_interpreter: /usr/bin/python3.12
    ansible_become: true
    ansible_become_method: sudo
    ansible_become_user: root
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_ssh_extra_args: '-o StrictHostKeyChecking=no'
```

**For Remote KVM host**
```bash
$ cat inventory/kvm-remote.yml 
all:
  hosts:
    remote-kvm-host:
      ansible_host: 192.168.100.108
      ansible_user: root
      ansible_connection: ssh
  vars:
    ansible_python_interpreter: /usr/bin/python3.12
    ansible_become: true
    ansible_become_method: sudo
    ansible_become_user: root
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
    ansible_ssh_extra_args: '-o StrictHostKeyChecking=no'
  children:
    kvm_hosts:
      hosts:
        remote-kvm-host:

```
---

## Create Guest Machines Input File
In order to create KVM guest machines, please provide an yaml file matching [guest-machines-input.yml](./guest-machines-input.yml) format.

- Configure cloud-init based on your requirements.
- Ensure guest machine networks are presented on KVM host.
  - Follow [Create Additional KVM Networks](#create-additional-kvm-networks) to create additional networks on KVM host.

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
Run below command to prepare target KVM host for capabilities listed in `setup.sh -i`. This option ensure KVM host has:

1. Cloud images `cloud_images` defined in [all.yml](./inventory/group_vars/all.yml).
2. Default KVM network `KVM_NETWORKS` defined in [all.yml](./inventory/group_vars/all.yml) for guest machines.
```bash
./setup.sh -p
```

**NOTE:** Additional networks can be created using `-n` option. Review [Create Additional KVM Networks](#create-additional-kvm-networks) for more information.

---

## Build and Management of KVM Guest Machines
Based on supported images & networks, create a yaml file for machines to be build for defined properties. Review [guest-machines-payload.yml](./guest-machines-payload.yml) for more information.

User will be prompted to provide input on following actions after the machines are created:
- Update OS
- Lifecycle Management of new built machines
  - Create snapshot

```bash
./setup.sh -b [guest-machines-payload.yml]
```

---

## Lifecycle Management of Guest Machines
Run below command for lifecycle management options of the guest machines.

```bash
./setup.sh -l [guest-machines-payload.yml]
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

**Create Networks:**
```bash
./setup.sh -n [custom-resources/openstack-networks.yml]
```
---