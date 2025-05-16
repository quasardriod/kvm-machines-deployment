#!/bin/bash

if ! which yq > /dev/null 2>&1;then
    sudo dnf install yq -y -q
fi

function kvm_packages(){
	sudo dnf install -y -q \
	guestfs-tools linux-system-roles
}

kvm_packages
