# KVM Machines Deployment and Customization


## Requirements
- Clone galaxy-roles:
```bash
git submodule add --force https://github.com/quasarstack/galaxy.git galaxy-roles
```


## Create KVM Guest Template
```bash
$ ansible-playbook playbooks/kvm-guest-template.yml \
    -e template_default_vars=$PWD/galaxy-roles/kvm-guest-template/defaults/main.yml
```

- [Configure KVM Guest Template](./docs/template-config.md)