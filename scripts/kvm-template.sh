#!/bin/bash

TEMPLATE_MACHINE_INVENTORY="inventory/kvm-template-machine"
PB="playbooks/kvm-template.yml"

ansible-playbook -i $TEMPLATE_MACHINE_INVENTORY $PB
