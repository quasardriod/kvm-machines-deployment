#!/bin/bash

# set -eo pipefail
# User provided yaml file to overwrite IMAGE_STORE location
default_vars_override_option=""
source scripts/constant.sh

# Vars for remote KVM host
remote_kvm_host_inventory="inventory/kvm-remote.yml"
local_kvm_host_inventory="inventory/kvm-local"

function set_virsh(){
    if [ -z $LIBVIRT_DEFAULT_URI ]; then
        echo "Please set LIBVIRT_DEFAULT_URI environment variable"
        exit 1
    fi

    VIRSH_CMD="virsh --connect $LIBVIRT_DEFAULT_URI"
}
function pre_checks(){
    # Ensure python3.12 is installed
    if ! command -v python3.12 &> /dev/null; then
        echo "python3.12 could not be found. Please install python3.12."
        exit 1
    fi

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
        generate_kvm_host_inventory

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

    user_consent
    set_virsh_connection
    generate_kvm_host_inventory

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

        # Call playbook to start building machines
        
        echo "local_kvm_host_inventory: $local_kvm_host_inventory"
        echo "build_pb: $build_pb"
        echo "guest_machines_payload: $guest_machines_payload"
        echo "default_vars_override_option: $default_vars_override_option"
        echo "build_artifacts: $build_artifacts"
        exit 0
        ansible-playbook -i $local_kvm_host_inventory $build_pb \
        -e @$guest_machines_payload $default_vars_override_option \
        -e build_artifacts=$build_artifacts -vvvv

        if [ $? -ne 0 ]; then
            error "\nERROR: Failed to build machines\n"
            exit 1
        fi

        # For now guest OS update supported only when VMs built on local KVM host
        if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
            update_guest_os
        fi

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
    echo "Usage: $0 [options]"
    echo "Options:"
    echo " -p                    Prepare KVM Host"
    echo " -b [job-inputs.yml]   Build and Configure KVM guests, required: [job-inputs.yml]"
    echo " -i                    List available images and properties"
    echo " -l [job-inputs.yml]   Life-cycle Management of KVM guests, required: [job-inputs.yml]"
	echo " -h                    help, this message"
    echo " -n [network.yml]      Create additional networks on KVM host"
	echo
	exit 0
}

while getopts 'ihpl:b:n:' opt; do
    case $opt in
        b) 
            if [ -z "$OPTARG" ]; then
                echo "Error: -b requires an argument."
                usage
                exit 1
            fi
            main "$OPTARG"
            ;;
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
