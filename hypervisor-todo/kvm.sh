#!/bin/bash

source scripts/constant.sh

[ -z $1 ] && error "\nERROR: Provide inventory file in 1st argument\n" && exit 1
if [ ! -f $1 ];then
    error "\nERROR: Inventory file: $1 not found\n"
    exit 1
fi

KVM_HOST_INVENTORY=$1
# PB="hypervisor/kvm.yml"
PB="hypervisor/ovs.yml"

ansible-playbook -i $KVM_HOST_INVENTORY $PB
