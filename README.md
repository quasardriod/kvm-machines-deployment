## Create KVM Guest Template
```bash
$ ansible-playbook playbooks/kvm-guest-template.yml \
    -e template_default_vars=$PWD/galaxy-roles/kvm-guest-template/defaults/main.yml
```
