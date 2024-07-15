# KVM Guest Template Config

## Requirements
- Setup [inventory](../inventory/template-machine)
- Test Connectivity
```bash
$ ansible all -i inventory/template-machine -m ping
ubuntu | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

# Optional Pre-requisites  
- Create Snapshot
```bash
$ virsh snapshot-create-as ubuntu2204 --name base
```

- Additional Commands
```bash
# Delete snapshot
$ virsh snapshot-delete ubuntu2204 --snapshotname base

# List snapshot
$ virsh snapshot-list ubuntu2204

# Revert Snapshot
$ virsh snapshot-revert ubuntu2204 --snapshotname base
```

## Implementation
1. Configure Template Guest VM
```bash
$ ansible-playbook -i inventory/template-machine playbooks/common/template-os-config.yml
```