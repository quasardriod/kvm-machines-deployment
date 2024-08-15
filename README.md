- [Introduction](#introduction)
- [Required Params](#required-params)
- [Define New VM details](#define-new-vm-details)
- [Create VM](#create-vm)

## Introduction
[What is KVM](https://www.redhat.com/en/topics/virtualization/what-is-KVM)

## Required Params
[constant.yaml](./scripts/constant.yaml) is used to define necessary params for KVM guests deployment. **User must** review `constant.yaml` for detailed information and make changes as required to match your environment.

## Define New VM details
By default [data.yaml](./data.yaml) is used to define new VMs you want to create. You can use your own custom file name.

```yaml
dpdk:           # Target VM type or intended use or app you may deploy on these VMs
- type: machine # VM role in app deployment. If not sure on specific role of VM, set `machine`
  name: dpdk    # VM name
  cpu: 4        # CPU
  memory: 4096  # Memory
  count: 2      # No. of machines to be created. If count is 1, machine name would be same as `name` defined above. If count is more than one, `01, 02` will be appended subsequently in `name` given above
  nic: 2        # No. of Network interface attach to VM. Based on No. of nic, networks listed below will be used in order. Minimum 1.
  networks:     # Provide KVM networks, minimum 1
  - default
  - tenant

k8s:
- type: master
  name: k8s-master
  cpu: 4
  memory: 4096 
  count: 1
  nic: 1
  networks: 
  - default
- type: worker
  name: k8s-w
  cpu: 2
  memory: 2048
  count: 2
  nic: 1
  networks: 
  - default
```

## Create VM
- With default [data.yaml](./data.yaml).
```bash
./run.sh -b
```

- With any custom file.
```bash
VMS_DATA="<full path of the file>" ./run.sh -b
```
