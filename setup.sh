#!/bin/bash

# set -eo pipefail
source scripts/constant.sh
build_artifacts_dir=/tmp/build-artifacts

# Following artifacts are created by the ansible playbook
# ansible-inventory of new created machines
inventory_artifact=$build_artifacts_dir/ansible-inventory

function pre_checks(){
    # Check if the ansible-playbook command is available
    if ! command -v ansible-playbook &> /dev/null; then
        echo "ansible-playbook could not be found. Please install Ansible."
        exit 1
    fi
    # Check if the yq command is available
    if ! command -v yq &> /dev/null; then
        echo "yq could not be found. Please install yq."
        exit 1
    fi
    # Check if the ssh-keygen command is available
    if ! command -v ssh-keygen &> /dev/null; then
        echo "ssh-keygen could not be found. Please install OpenSSH."
        exit 1
    fi
    
    [ ! -d $build_artifacts_dir ] && mkdir -p $build_artifacts_dir
}

# Run pre-checks
pre_checks




function prepare_kvm_host(){
    ansible-playbook -i inventory/kvm-local ansible/hypervisor/pb-prepare-kvm.yml
}

function main(){
    build_pb="ansible/build-guests/pb-build-guest.yml"
    # [[ -z $1 ]] && echo "Please provide the job-inputs.yml file" && exit 1   
    # job_inputs_file=$1
    # [ ! -f $job_inputs_file ] && echo "File $job_inputs_file not found" && exit 1
    
    # ansible-playbook -i inventory/kvm-local $build_pb \
    # -e @$job_inputs_file -e "build_artifacts_dir=$build_artifacts_dir" \
    # -e "inventory_artifact=$inventory_artifact" \

    info "\nUpdate OS of guest machines from $inventory_artifact\n"
    info_y "------------------------------------------------\n"
    ansible-inventory -i $inventory_artifact --list
    info_y "\n----------------------------------------------\n"
    
    configure_pb="ansible/configure-guests/pb-configure-guest.yml"
    read -p "Continue with ansible-playbook to update guest machines? [y/N]: " update_os
    if [[ ${update_os,,} == "y" ]] || [[ ${update_os,,} == "yes" ]];then
        ansible-playbook -i $inventory_artifact $configure_pb
    else
        info_y "\nSkipping OS update...\n" && exit 0
    fi
   
}

function kvm_host_capabilities(){
    set_virsh_connection
    
    # Show available images and properties
    info_y "\nKVM hypervisor capabilities:\n"
    info_y "------------------------------------------------\n"
    info "\nAvailable images:\n"
    info "-----------------\n"
    yq eval '.cloud_images' ansible/vars/cloud-images.yml
    
    info "\nBuild Image are/will be stored in:\n"
    info "---------------------\n"
    yq eval '.IMAGE_TEMPLATE_STORE' inventory/group_vars/all.yml

    info "\nNew Created KVM Guest disks will be stored in:\n"
    info "---------------------\n"
    yq eval '.IMAGES_STORE' inventory/group_vars/all.yml

    info "\nShow KVM bridge Networks:\n"
    info "---------------------\n"
    for network in $(yq eval '.KVM_NETWORKS[]' inventory/group_vars/all.yml); do
        info "$network:\n"
        success "\tdhcp lease: $($VIRSH_CMD net-dumpxml $network|grep -E range|xargs)\n"
    done

    info "\nShow cloud-config default params\n"
    info "---------------------\n"
    success "Default cloud-init user: $(yq eval '.CLOUD_USER' inventory/group_vars/all.yml)\n"
    info_y "\nNOTE: To override the default user to be created by cloud-init,\nplease set the variable cloud_user in your job-inputs.yml file\n"
}

usage(){
	echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo " -p Prepare KVM Host"
    echo " -m <job-inputs.yml> Main playbook to build KVM guests, required: [job-inputs.yml]"
    echo " -i List available images and properties"
	echo " -h help, this message"
	echo
	exit 0
}

while getopts 'ihpm:' opt; do
	case $opt in
		m) main "$OPTARG";;
		h) usage;;
		p) prepare_kvm_host;;
        i) kvm_host_capabilities;;
		\?|*)	echo "Invalid Option: -$OPTARG" && usage;;
	esac
done

shift $((OPTIND - 1))
exit 0