#!/bin/bash

TEMPLATE_MACHINE_INVENTORY="inventory/dpdk-inv"
PB="playbooks/dpdk.yml"

ansible-playbook -i $TEMPLATE_MACHINE_INVENTORY $PB
