#!/usr/bin/env bash

# Run ansible playbook to create VM on KVM host
ansible-playbook -i kvm-host.yml deploy-vm.yml
