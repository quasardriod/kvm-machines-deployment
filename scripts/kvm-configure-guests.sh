#!/bin/bash

[ -z $1 ] && error "\nERROR: Provide inventory file in 1st argument\n" && exit 1
if [ ! -f $1 ];then
    error "\nERROR: Inventory file: $1 not found\n"
    exit 1
fi

MACHINES_INVENTORY=$1
PB="playbooks/kvm-configure-guests.yml"

ansible-playbook -i $MACHINES_INVENTORY $PB
