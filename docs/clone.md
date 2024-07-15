# Create and Manage Virtual Machine Clones

- Create Machine Clone Manually
```bash
$ virt-clone -o ubuntu2204 -n new_machine --auto-clone
```

- Create Machine Clones
```bash
$ ansible-playbook -i inventory/kvm-hosts playbooks/common/clone-machines.yml 
```

- Tweak CPU and Memory of new Machines
```bash
$ ansible-playbook -i inventory/kvm-hosts playbooks/common/tweak-cpu-mem.yml 
```
