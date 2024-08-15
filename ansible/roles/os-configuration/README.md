# Custom OS Configuration

This role provides capability to make custom OS configure as listed below:

- Set Hostname
- Set Sudo access for {{ansible_user}}
- Install Public Key on target machines
- Set Root password
- Allow Root logic over ssh

## Variables Annotation
- In [Default Vars](./defaults/main.yml), `pub_key_on_localhost` is set to read public key from localhost. Overwrite default value using `-e pub_key_on_localhost=<path of public key on localhost>`

- Using `-e root_password=` provide root password to set root password
- Using `-e install_root_pub_key=true`, install `pub_key_on_localhost` public key for root user. Default is set to `true`. Overwrite root public key using `-e root_pub_key_on_localhost=<path of public key on localhost>`.

## Implementation
1. Setup Inventory as below, example: /tmp/hosts
```
k8s-m01 ansible_host=192.168.10.112
k8s-w01 ansible_host=192.168.10.98

[all:vars]
ansible_user=ubuntu
ansible_password=redhat
```

2. Create playbook

```yaml
---

- hosts: all
  gather_facts: true
  become: yes

  roles:
  - role: os-configuration
```

3. Run Playbook
```bash
$ ansible-playbook -i /tmp/hosts pb.yml
```