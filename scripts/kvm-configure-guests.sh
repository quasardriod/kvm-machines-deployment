#!/bin/bash

cd ../

MACHINES_INVENTORY="inventory/openstack-inv"
PB="playbooks/kvm-configure-guests.yml"

[ ! -f $MACHINES_INVENTORY ] && echo "ERROR: Inventory file: $MACHINES_INVENTORY not found" && exit 1
ansible-playbook -i $MACHINES_INVENTORY $PB
