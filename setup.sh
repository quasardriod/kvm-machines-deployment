#!/bin/bash

# set -eo pipefail
# User provided yaml file to overwrite IMAGE_STORE location

# set -x
default_vars_override_option=""
source scripts/formatter.sh
source scripts/constant.sh
source scripts/assert.sh

# Vars for remote KVM host
remote_kvm_host_inventory="inventory/kvm-remote.yml"
local_kvm_host_inventory="inventory/kvm-local.yml"


function pre_checks(){
    assert_python3_installed
    assert_ansible_core
    assert_yq_installed
    assert_ansible_collections
    assert_ssh_keygen_installed
    assert_virsh_installed
    assert_libvirt_uri_connection
    set_virsh_cli
}

# Run pre-checks
if [[ ! " $@ " =~ " -h" ]] || [[ ! " $@ " =~ " --help" ]]; then
    pre_checks
elif [[ ! " $@ " =~ " -k" ]]; then
    pre_checks
    assert_remote_kvm_for_virsh
fi

function prepare_kvm_host(){
    set_virsh_connection
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        ansible-playbook -i $local_kvm_host_inventory ansible/hypervisor/pb-prepare-kvm.yml \
        $default_vars_override_option
    fi

    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        remote_kvm
        ansible-playbook -i $remote_kvm_host_inventory ansible/hypervisor/pb-prepare-kvm.yml \
        $default_vars_override_option
    fi
}

function show_final_info(){
    build_artifacts=$1
    success "\n-----NOTE:-----\n\tGenerated Build Artifacts: $build_artifacts\n"
}

function update_guest_os(){
    # Guest machines inventory file created as build artifacts
    # Check machine_artifacts in all.yml for location

    configure_pb="ansible/configure-guests/pb-configure-guest.yml"
    inventory_artifact=$(find $build_artifacts -name guests-inventory-*.yml | head -n 1)

    if [ ! -f $inventory_artifact ]; then
        error "\nERROR: $inventory_artifact not found\n"
        exit 1
    fi

    info "\nUpdate OS of guest machines from $inventory_artifact\n"
    info_y "------------------------------------------------\n"
    ansible-inventory -i $inventory_artifact --list
    info_y "\n----------------------------------------------\n"
    
    read -p "Continue with ansible-playbook to update guest machines? [y/N]: " update_os
    if [[ ${update_os,,} == "y" ]] || [[ ${update_os,,} == "yes" ]];then
        ansible-playbook -i $inventory_artifact $configure_pb $default_vars_override_option
        if [ $? -ne 0 ]; then
            error "\nERROR: Failed to update guest machines\n"
            exit 1
        fi

    else
        info_y "\nSkipping OS update...\n"
    fi
}

function guests_lcm(){
    declare -a operations=("Snapshot" "Revert" "Delete" "Start" "Stop" "Pause" "Unpause" "Shutdown")
    lcm_pb="ansible/guests-lcm/lifecycle-management.yml"

    if [ -z $guest_machines_payload ]; then
        set_virsh_connection

        [[ -z $1 ]] && echo "Please provide the job-inputs.yml file" && exit 1   
        guest_machines_payload=$1
        [ ! -f $guest_machines_payload ] && echo "File $guest_machines_payload not found" && exit 1
    fi

    info "\nINFO: Following VMs will be managed:\n"
    info "------------------------------------------------\n"
    yq eval '.kvm_guest_machines[]|.name' $guest_machines_payload
    info "\n------------------------------------------------\n"
    
    if [ -z $operation ];then
        info_y "\nINFO: Select operation to perform on KVM guests\n"
        info_y "------------------------------------------------\n"
        for index in "${!operations[@]}"; do
            echo -e "$index: ${operations[$index]}"
        done
        echo -e "\nHit Enter to skip operations\n"
        read -p "Select operation index: " operation_choice

        # Check if the input is a valid number and within the range of operations
        if [ -z $operation_choice ];then
            info "\nINFO: No operation selected. Skipping...\n"
            exit 1
        elif [[ ! "$operation_choice" =~ ^[0-9]+$ ]] || [[ $operation_choice -lt 0 ]] || [[ $operation_choice -ge ${#operations[@]} ]]; then
            error "\nERROR: Invalid operation index. Please select a valid index.\n"
            exit 1
        fi
        operation=${operations[$operation_choice]}
    else
        info_y "\nINFO: User provided operation: $operation\n"
        # Ensure the given operation exists in the operations array
        if [[ ! " ${operations[@]} " =~ " ${operation} " ]]; then
            error "\nERROR: Selected operation is not valid. Please select a valid operation.\n"
            exit 1
        fi
    fi
    
    success "\nINFO: Performing operation: ${operation}\n"

    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        ansible-playbook -i $local_kvm_host_inventory $lcm_pb \
        -e @$guest_machines_payload -e operation=${operation,,} $default_vars_override_option
        
        [[ $? -ne 0 ]] && error "\nERROR: Failed to perform operation: $operation\n" && exit 1
    fi
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        ansible-playbook -i $remote_kvm_host_inventory $build_pb -e @$guest_machines_payload \
        -e "inventory_artifact=$inventory_artifact" -e operation=${operation,,} \
        $default_vars_override_option

        [[ $? -ne 0 ]] && error "\nERROR: Failed to perform operation: $operation\n" && exit 1
    fi
}

function main(){
    guest_machines_payload=$1
    [ ! -f $guest_machines_payload ] && echo "File $guest_machines_payload not found" && exit 1
    
    set_virsh_connection

    # Artifacts location on ansible controller
    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        build_artifacts="/tmp/artifacts/kvm_local"
    fi
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        build_artifacts="/tmp/artifacts/kvm_remote"
    fi

    [[ ! -d $build_artifacts ]] && mkdir -p $build_artifacts

    info_y "Build artifacts on Ansible Controller: $build_artifacts\n"
    info_y "Build artifacts on KVM host: $(yq .kvm_artifacts_dir inventory/group_vars/all.yml)\n"

    build_pb="ansible/build-guests/pb-build-guest.yml"
      
    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then

        if [ ! -f $local_kvm_host_inventory ]; then
            error "\nERROR: $local_kvm_host_inventory not found\n"
            exit 1
        fi
        
        user_consent $local_kvm_host_inventory localhost

        # Call playbook to start building machines        
        ansible-playbook -i $local_kvm_host_inventory $build_pb \
        -e @$guest_machines_payload $default_vars_override_option \
        -e build_artifacts=$build_artifacts

        if [ $? -ne 0 ]; then
            error "\nERROR: Failed to build machines\n"
            exit 1
        fi

        # For now guest OS update supported only when VMs built on local KVM host
        update_guest_os

        # Prompt user to take a snapshot of the new machine
        read -p "Do you want to take a snapshot of the newly created machines? [y/N]: " take_snapshot
        if [[ ${take_snapshot,,} == "y" ]] || [[ ${take_snapshot,,} == "yes" ]]; then
            info "\nINFO: Taking snapshot of the newly created machines\n"
            # Shutdown the machines before taking snapshot
            info "\nINFO: Shutdown the machines before taking snapshot\n"
            operation="Shutdown"
            guests_lcm

            # Take snapshot of the new created machines
            operation="Snapshot"
            guests_lcm

            # Start the machines after snapshot
            operation="Start"
            guests_lcm
        else
            info "\nINFO: Skipping snapshot creation...\n"
        fi
    fi
    
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        if [ ! -f $remote_kvm_host_inventory ]; then
            error "\nERROR: $remote_kvm_host_inventory not found\n"
            exit 1
        fi

        ansible-playbook -i $remote_kvm_host_inventory $build_pb \
        -e @$guest_machines_payload -e "build_artifacts=$build_artifacts" \
        $default_vars_override_option

        if [ $? -ne 0 ]; then
            error "\nERROR: Failed to build machines\n"
            exit 1
        fi

        info_y "\nAlert: Guest OS update is not supported on remote KVM host\n" 
        
        # Shutdown the machines before taking snapshot
        info "\nINFO: Shutdown the machines before taking snapshot\n"
        operation="Shutdown"
        guests_lcm

        # Take snapshot of the new created machines
        operation="Snapshot"
        guests_lcm

        # Start the machines after snapshot
        operation="Start"
        guests_lcm
    fi

    # Always run at last
    show_final_info $build_artifacts

    # Show all IP addresses of the created machines
    info_y "\nINFO: All IP addresses of the created machines\n"
    for guest in $(yq eval '.kvm_guest_machines[]|.name' $guest_machines_payload); do
        info_y "------------- $guest -------------------------\n"
        $VIRSH_CMD domifaddr $guest
        info_y "\n------------------------------------------------\n"
    done
}

function kvm_host_capabilities(){
    set_virsh_connection

    # Show available images and properties
    info_y "\nKVM hypervisor capabilities:\n"
    info_y "------------------------------------------------\n"
    info "\nAvailable images:\n"
    info "-----------------\n"
    yq eval '.cloud_images' inventory/group_vars/all.yml
    
    info "\nBuild Image are/will be stored in:\n"
    info "---------------------\n"
    yq eval '.IMAGE_TEMPLATE_STORE' inventory/group_vars/all.yml

    info "\nNew Created KVM Guest disks will be stored in:\n"
    info "---------------------\n"
    yq eval '.IMAGES_STORE' inventory/group_vars/all.yml

    info "\nShow KVM bridge Networks:\n"
    info "---------------------"
    for network in $($VIRSH_CMD net-list --all --name); do
        info_y "\n$network: -> dhcp lease: $($VIRSH_CMD net-dumpxml $network | grep -E range | xargs)"
    done
    echo

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

function additional_kvm_networks(){
    if [ -z $1 ];then
        error "\nPlease provide the network yaml file\n"
        info_y "Visit [Create Additional KVM Networks] for more information.\n"
        exit 1
    fi
    network_file=$1
    [ ! -f $network_file ] && error "\nFile $network_file not found\n" && exit 1

    networks_count=$(yq eval '.additional_kvm_networks | length' $network_file)
    if [ $networks_count -eq 0 ]; then
        error "\nNo additional_kvm_networks found in $network_file\n"
        exit 1
    fi
    
    info_y "\nINFO: Following additional networks will be created on KVM host:\n"
    info_y "------------------------------------------------\n"
    yq eval '.additional_kvm_networks' $network_file
    info_y "\n------------------------------------------------\n"

    pause
    
    set_virsh_connection

    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        ansible-playbook -i $local_kvm_host_inventory ansible/hypervisor/pb-prepare-kvm.yml \
        $default_vars_override_option -e @$network_file -e networks=true -e images=false
    fi

    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        remote_kvm
        ansible-playbook -i $remote_kvm_host_inventory ansible/hypervisor/pb-prepare-kvm.yml \
        $default_vars_override_option
    fi
}

usage(){
	echo
    info_y "\nAnsible based scripts to prepare KVM host, build and manage KVM guest machines.\n"
    echo "Usage: $0 [options] [arguments]"
    echo "Options:"
    echo "-------------------------------------"
    echo " -g           Generate KVM host inventory based on LIBVIRT_DEFAULT_URI"
    echo " -k           Install KVM Host dependencies"
    echo " -p           Prepare KVM Host"
    echo " -b [argv]    Build and Configure KVM guests. Required: [guest-machines-payload.yml]"
    echo " -i           List available images and properties"
    echo " -l [argv]    Life-cycle Management of KVM guests. Required: [guest-machines-payload.yml]"
	echo " -h           help, this message"
    echo " -n [argv]    Create additional networks on KVM host. Optional: [additional-networks.yml]"
	echo
	exit 0
}

while getopts 'ihgkpl:b:n:' opt; do
    case $opt in
        b) 
            if [ -z "$OPTARG" ]; then
                echo "Error: -b requires an argument."
                usage
                exit 1
            fi
            main "$OPTARG"
            ;;
        g) generate_kvm_host_inventory;;
        n) 
            if [ -z "$OPTARG" ]; then
                echo "Error: -n requires an argument."
                usage
                exit 1
            fi
            additional_kvm_networks "$OPTARG"
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
        k) install_kvm_host_dependencies;;
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
