#!/bin/bash

# set -eo pipefail
source scripts/constant.sh
build_artifacts_dir=/tmp/build-artifacts

# Following artifacts are created by the ansible playbook
# ansible-inventory of new created machines
inventory_artifact=$build_artifacts_dir/ansible-inventory

# Vars for remote KVM host
remote_kvm_host_inventory="inventory/kvm-remote.yml"
local_kvm_host_inventory="inventory/kvm-local.yml"

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
}

# Run pre-checks
pre_checks

function prepare_kvm_host(){
    set_virsh_connection
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        ansible-playbook -i inventory/kvm-local ansible/hypervisor/pb-prepare-kvm.yml -b 
    fi

    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        remote_kvm
        ansible-playbook -i inventory/kvm-remote ansible/hypervisor/pb-prepare-kvm.yml \
        -e LIBVIRT_DEFAULT_URI=$LIBVIRT_DEFAULT_URI
    fi
}

function update_guest_os(){
    configure_pb="ansible/configure-guests/pb-configure-guest.yml"

    info "\nUpdate OS of guest machines from $inventory_artifact\n"
    info_y "------------------------------------------------\n"
    ansible-inventory -i $inventory_artifact --list
    info_y "\n----------------------------------------------\n"
    
    read -p "Continue with ansible-playbook to update guest machines? [y/N]: " update_os
    if [[ ${update_os,,} == "y" ]] || [[ ${update_os,,} == "yes" ]];then
        ansible-playbook -i $inventory_artifact $configure_pb
    else
        info_y "\nSkipping OS update...\n" && exit 0
    fi
}

function guests_lcm(){
    declare -a operations=("Snapshot" "Revert" "Delete" "Start" "Stop" "Pause" "Unpause" "Shutdown")
    lcm_pb="ansible/guests-lcm/lifecycle-management.yml"

    if [ -z $job_inputs_file ]; then
        set_virsh_connection
        generate_kvm_host_inventory

        [[ -z $1 ]] && echo "Please provide the job-inputs.yml file" && exit 1   
        job_inputs_file=$1
        [ ! -f $job_inputs_file ] && echo "File $job_inputs_file not found" && exit 1
    fi

    info_y "\nINFO: Select operation to perform on KVM guests\n"
    info_y "------------------------------------------------\n"
    for index in "${!operations[@]}"; do
        echo -e "$index: ${operations[$index]}"
    done
    echo -e "\nHit Enter to skip operations\n"
    read -p "Select operation index: " operation

    # Check if the input is a valid number and within the range of operations
    if [ -z $operation ];then
        info "\nINFO: No operation selected. Skipping...\n"
        exit 1
    elif [[ ! "$operation" =~ ^[0-9]+$ ]] || [[ $operation -lt 0 ]] || [[ $operation -ge ${#operations[@]} ]]; then
        error "\nERROR: Invalid operation index. Please select a valid index.\n"
        exit 1
    fi

    success "\nINFO: Selected operation: ${operations[$operation]}\n"

    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        ansible-playbook -i $local_kvm_host_inventory $lcm_pb \
        -e @$job_inputs_file -e operation=${operations[$operation],,} \
        -b
    fi
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        ansible-playbook -i $remote_kvm_host_inventory $build_pb \
        -e @$job_inputs_file -e "build_artifacts_dir=$build_artifacts_dir" \
        -e "inventory_artifact=$inventory_artifact" -e operation=${operations[$operation],,}
    fi
}

function main(){
    set_virsh_connection
    generate_kvm_host_inventory

    info_y "\nCleaning up $build_artifacts_dir\n"
    [ -d $build_artifacts_dir ] && rm -rf $build_artifacts_dir

    info_y "Build artifacts will be stored in: $build_artifacts_dir\n"
    mkdir -p $build_artifacts_dir

    build_pb="ansible/build-guests/pb-build-guest.yml"
   
    [[ -z $1 ]] && echo "Please provide the job-inputs.yml file" && exit 1   
    job_inputs_file=$1
    [ ! -f $job_inputs_file ] && echo "File $job_inputs_file not found" && exit 1
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then

        if [ ! -f $local_kvm_host_inventory ]; then
            error "\nERROR: $local_kvm_host_inventory not found\n"
            exit 1
        fi
        ansible-playbook -i $local_kvm_host_inventory $build_pb \
        -e @$job_inputs_file -e "build_artifacts_dir=$build_artifacts_dir" \
        -e "inventory_artifact=$inventory_artifact"

        if [ $? -ne 0 ]; then
            error "\nERROR: Failed to build machines\n"
            exit 1
        fi

        # For now guest OS update supported only when VMs built on local KVM host
        if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
            update_guest_os
        fi

        # Prompt for life-cycle management operations on new created machines
        read -p "Do you want to perform life-cycle management operations on new created machines? [Y/n]: " lcm_input
        if [[ ${lcm_input,,} == "y" ]] || [[ ${lcm_input,,} == "yes" ]] || [[ -z $lcm_input ]];then
            guests_lcm
        else
            info_y "\nSkipping operation...\n"
        fi
    fi
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        if [ ! -f $remote_kvm_host_inventory ]; then
            error "\nERROR: $remote_kvm_host_inventory not found\n"
            exit 1
        fi

        ansible-playbook -i $remote_kvm_host_inventory $build_pb \
        -e @$job_inputs_file -e "build_artifacts_dir=$build_artifacts_dir" \
        -e "inventory_artifact=$inventory_artifact"
        
        if [ $? -ne 0 ]; then
            error "\nERROR: Failed to build machines\n"
            exit 1
        fi

        info "\nINFO: Guest OS update is not supported on remote KVM host\n" 
        
        # Prompt for life-cycle management operations on new created machines
        read -p "Do you want to perform life-cycle management operations on new created machines? [Y/n]: " lcm_input
        if [[ ${lcm_input,,} == "y" ]] || [[ ${lcm_input,,} == "yes" ]] || [[ -z $lcm_input ]];then
            guests_lcm
        else
            info_y "\nSkipping operation...\n"
        fi

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

    info "\nShow KVM Host CPU:\n"
    info "---------------------\n"
    $VIRSH_CMD nodeinfo
    
    info "\nShow KVM Host Memory:\n"
    info "---------------------\n"
    $VIRSH_CMD nodememstats

    info "\nShow cloud-config default params\n"
    info "---------------------\n"
    success "Default cloud-init user: $(yq eval '.CLOUD_USER' inventory/group_vars/all.yml)\n"
    info_y "\nNOTE: To override the default user to be created by cloud-init,\nplease set the variable cloud_user in your job-inputs.yml file\n"
}

usage(){
	echo
    echo "Usage: $0 [options]"
    echo "Options:"
    echo " -p                    Prepare KVM Host"
    echo " -m <job-inputs.yml>   Build and Configure KVM guests, required: [job-inputs.yml]"
    echo " -i                    List available images and properties"
    echo " -l <job-inputs.yml>   Life-cycle Management of KVM guests, required: [job-inputs.yml]"
	echo " -h                    help, this message"
	echo
	exit 0
}

while getopts 'ihpl:m:' opt; do
    case $opt in
        m) 
            if [ -z "$OPTARG" ]; then
                echo "Error: -m requires an argument."
                usage
                exit 1
            fi
            main "$OPTARG"
            ;;
        h) usage;;
        p) prepare_kvm_host;;
        i) kvm_host_capabilities;;
        l) 
            if [ -z "$OPTARG" ]; then
                echo "Error: -m requires an argument."
                usage
                exit 1
            fi
            guests_lcm "$OPTARG"
            ;;
        \?|*) 
            echo "Invalid Option: -$opt"
            usage
            exit 1
            ;;
    esac
done

# Handle -p and -l together, fallback to LIBVIRT_DEFAULT_URI if -l is not provided
# if [[ $OPTIND -gt 1 && $1 == "-p" ]]; then
#     prepare_kvm_host "$kvm_connection"
# fi

shift $((OPTIND - 1))
exit 0