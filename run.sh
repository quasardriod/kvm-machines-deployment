#!/bin/bash

set -eo pipefail
source scripts/constant.sh

function image_selector(){
	info "\nINFO: Select QCOW2 Linux images from below list...\n"
	list_images
	read -p "Image number [0]:  " _image_number
	if [[ -z $_image_number ]];then
		_image_number=$default_image
	elif ! echo ${!IMAGES[@]}|grep -E -q $_image_number;then
		error "\nERROR: Out of index\n"
		exit 1
	fi
	image_name=${IMAGES[$_image_number]}
	image_full_name=$image_name.$IMAGE_TYPE
	
	success "\n-> Selected image: $image_full_name\n"

	if [ ! -f $IMAGE_TEMPLATE_STORE/$image_full_name ];then
		download_image $image_full_name
	else
		success "INFO: Image $image_full_name already present in Image Store: $IMAGE_TEMPLATE_STORE\n"
	fi
}

function variant_selector(){
	info "\nINFO: Select supported OS Variant from the list...\n"
	list_variant
	read -p "Variant number [0]: " _variant_number
	if [[ -z $_variant_number ]];then
		_variant_number=$default_variant
	elif ! echo ${!VARIANTS[@]}|grep -E -q $_variant_number;then
		error "\nERROR: Out of index\n"
		exit 1
	fi
	variant_name=${VARIANTS[$_variant_number]}
	
	success "\n-> Selected Variant: $variant_name\n"
}

function read_vms_data(){
	info "\nINFO: Select deployment type on VMs...\n"
	list_vms_purpose
	read -p "Deployment Type [0]: " choice
	if [[ -z $choice ]];then
		choice=$default_deployment
	elif ! echo ${!VMS_PURPOSE[@]}|grep -E -q $choice;then
		error "\nERROR: Out of index\n"
		exit 1
	fi
	DEPLOYMENT_TYPE=${VMS_PURPOSE[$choice]}
	
	success "\n-> Selected deployment type: $DEPLOYMENT_TYPE\n"

	info "\nINFO: Load VMs data from $VMS_DATA for selected deployment\n"
	if [[ "$(yq .$DEPLOYMENT_TYPE $VMS_DATA)" == "null" ]];then
		error "\nERROR: Deployment Type: '$DEPLOYMENT_TYPE' not found in $VMS_DATA\n"
		exit
	fi
	info "\n$DEPLOYMENT_TYPE:\n"
	yq .$DEPLOYMENT_TYPE $VMS_DATA



}


function set_vms_properties(){
	DEPLOYMENT_TYPE=$1
	info_y "\nINFO: Selected Deployment Type: $DEPLOYMENT_TYPE\n"
    
	l=$(yq ".\"$DEPLOYMENT_TYPE\"|length" $VMS_DATA)
	if [[ $l == 1 ]];then
		_seq=0
	elif [[ $l > 1 ]];then
		_seq=$(seq 0 $(($l-1)))
	else
		error "\nERROR: No deployment match found\n"
		exit 1
	fi
	
	info "\nINFO: Following VMs will be created for...\n"
	create_inventory_file $DEPLOYMENT_TYPE
	
	for i in $_seq;do
		declare -a VMS_TO_BE_CREATED=()
		common_name=$(yq .$DEPLOYMENT_TYPE[$i].name $VMS_DATA)
		cpu=$(yq .$DEPLOYMENT_TYPE[$i].cpu $VMS_DATA)
		memory=$(yq .$DEPLOYMENT_TYPE[$i].memory $VMS_DATA)
		machine_role=$(yq .$DEPLOYMENT_TYPE[$i].type $VMS_DATA)
		count=$(yq .$DEPLOYMENT_TYPE[$i].count $VMS_DATA)
		ip_extra_args=$(yq .$DEPLOYMENT_TYPE[$i].ip_extra_args $VMS_DATA)
		
		if [ $count -eq 1 ];then
			VMS_TO_BE_CREATED+=($common_name)
		elif [ $count -gt 1 ];then
			start=1
			while [ $start -le $count ];do
				vm_name="${common_name}0${start}"
				VMS_TO_BE_CREATED+=($vm_name)
				start=$(($start+1))
			done
		fi
		info_y "\nMachine Role: $machine_role\n"
		for v in ${VMS_TO_BE_CREATED[@]};do
			echo $v
		done
		filtered_data "CPU: $cpu\nMemory: $memory"

		for v in ${VMS_TO_BE_CREATED[@]};do
			info_y "\n========= Processing VM: $v =========="
			info "\nINFO: Setting virtual disk..."
			
			# vm_disks function will provide VM_ROOT_DISK
			vm_disks $v $variant_name
			
			# Create VM
			# vm_install expects: vm=$1,DISK=$2,MEM=$3,VCPU=$4,VARIANT=$5
			# vm_install $v "$VM_ROOT_DISK" $memory $cpu $variant_name
			vm_install $v "$VM_ROOT_DISK" $variant_name $DEPLOYMENT_TYPE

			# Test network connectivity
			get_vm_ips $v

			if [ -z "${vm_ips}" ];then
				error "\nERROR: Failed to fetch IPs of VM: $v\n"
				exit 1
			fi
			for ip in ${vm_ips};do
				if ! grep -Eq ^$v $INVENTORY_FILE;then
					sed -i "1i ${v} ansible_host=${ip}" $INVENTORY_FILE
				fi
				vm_ansible_test $v
				break
			done
			info_y "\n========= Completed VM: $v ==========\n"
		done
	done
}


function vm_undefine(){
	vm=$1
	if [ "$(sudo virsh domstate $vm)" != "shut off" ];then
		sudo virsh destroy $vm
		sleep 10
	fi
	sudo virsh undefine $vm --remove-all-storage
}

function main(){
	image_selector
	variant_selector
	read_vms_data
	set_vms_properties $DEPLOYMENT_TYPE
}

usage(){
	echo
	echo " -b Build Virtual Machines on Local KVM"
	echo " -u Undefine and Remove a Virtual Machine, required: [vm_name]"
	echo " -h help, this message"
	echo
	exit 0
}

while getopts 'u:bh' opt; do
	case $opt in
		b) main;;
		h) usage;;
		u) vm_undefine ${OPTARG};;
		\?|*)	echo "Invalid Option: -$OPTARG" && usage;;
	esac
done

shift $((OPTIND - 1))
exit 0
