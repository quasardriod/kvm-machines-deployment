#!/bin/bash

# Set -eo pipefail
# set -e: Exit immediately if a command exits with a non-zero status.
# set -o pipefail: This option causes a pipeline to return the exit status of the last command in the pipeline that failed, or zero if no command failed.
# set -eo pipefail


##### Block to color message output
# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
# Clear the color after that
clear='\033[0m'

function info(){
    printf "${cyan}$1${clear}"
}

function error(){
    printf "${red}$1${clear}"
}

function success(){
    printf "${green}$1${clear}"
}

function filtered_data(){
    printf "${magenta}$1${clear}"
}

function info_y(){
    printf "${yellow}$1${clear}"
}
#########

function pause(){
    echo
    read -p "Continue [Y/n]: " pause_response
    
    if [[ ${pause_response,,} == "n" ]] || [[ ${pause_response,,} == "no" ]];then
        info_y "\nBye...\n"
        exit 2
    elif [[ ${pause_response,,} == "y" ]] || [[ ${pause_response,,} == "yes" ]] || [[ -z $pause_response ]];then
        info_y "\nContinue...\n"
    else
        error "\nERROR: Wrong input...\n"
        exit 1
    fi
}

# Configure virsh connection
function set_virsh_connection(){
    # Check if libvirt is installed
    if ! command -v virsh &> /dev/null; then
        error "libvirt is not installed. Please install it first.\n"
        exit 1
    fi

    if [[ -z $LIBVIRT_DEFAULT_URI ]]; then
        error "\nERROR: 'LIBVIRT_DEFAULT_URI' is not exported for QEMU connection.\n"

        read -r -p "Do you wish to set it now? [y/N]: " consent
        if [[ ${consent,,} == "y" ]] || [[ ${consent,,} == "yes" ]];then
            info_y "\nINFO: Please provide the QEMU connection string:\n"
            info_y "------------------------------------------------\n"
            info_y "For local KVM host: export LIBVIRT_DEFAULT_URI='qemu:///system'\n"
            info_y "For remote KVM host: export LIBVIRT_DEFAULT_URI='qemu+ssh://root@<remote-kvm-host>/system'\n"
            info_y "------------------------------------------------\n"
            read -p "LIBVIRT_DEFAULT_URI: " LIBVIRT_DEFAULT_URI
            
            export LIBVIRT_DEFAULT_URI=$LIBVIRT_DEFAULT_URI
            if [[ -z $LIBVIRT_DEFAULT_URI ]]; then
                error "\nERROR: 'LIBVIRT_DEFAULT_URI' is not set, please set it and re-run the script.\n"
                exit 1
            fi

            success "\nINFO: LIBVIRT_DEFAULT_URI is set to $LIBVIRT_DEFAULT_URI\n"
            pause
        else
            error "\nBye...\n"
            exit 2
        fi
    fi
    info_y "\nINFO: LIBVIRT_DEFAULT_URI is set to $LIBVIRT_DEFAULT_URI\n"
    info "\nINFO: Preparing $LIBVIRT_DEFAULT_URI KVM host\n"
    info "------------------------------------------------\n" 

    if [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        # Run block when kvm connection is local: qemu:///system
        if [ "$(id -u)" -ne 0 ]; then
            # Check if the user has passwordless sudo privileges
            if ! sudo -n true &> /dev/null; then
                error "You do not have passwordless sudo privileges. Please run the script as a user with passwordless sudo privileges.\n"
                exit 1
            fi
            # Check if the user has passwordless sudo privileges for virsh
            if ! sudo -n virsh list &> /dev/null; then
                error "You do not have passwordless sudo privileges for virsh. Please run the script as a user with passwordless sudo privileges for virsh.\n"
                exit 1
            fi
            info "INFO: Current user is not root, setting up sudo for virsh command\n"

            # Ensure libvirtd service is running
            if ! sudo systemctl is-active --quiet libvirtd; then
                info "INFO: Starting libvirtd service...\n"
                if ! sudo systemctl start libvirtd; then
                    error "Failed to start libvirtd service. Please check the service status.\n"
                    exit 1
                fi
                info "INFO: libvirtd service started successfully.\n"
            fi
            export VIRSH_CMD="sudo virsh"
        else
            export VIRSH_CMD="virsh"
        fi
    fi

    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/root@.+\/system ]]; then
        # Run block when kvm connection to remote machine
        # Check if the user has passwordless sudo privileges for virsh
        if ! sudo virsh list &> /dev/null; then
            error "You do not have passwordless sudo privileges for virsh. Please run the script as a user with passwordless sudo privileges for virsh.\n"
            exit 1
        fi
        export VIRSH_CMD="virsh"     
    fi
    info_y "INFO: Using virsh command: $VIRSH_CMD\n"
}

# Generate ansible inventory for remote KVM host on the fly
function generate_kvm_host_inventory(){
    echo "FIXME" && exit 1
    # https://www.bashsupport.com/bash/variables/bash_rematch/

    # Generate inventory from remote QEMU connection LIBVIRT_DEFAULT_URI
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh://([^@]+)@([^/]+)/system$ ]]; then

        info_y "\nINFO: Generating ansible inventory for remote KVM host: $LIBVIRT_DEFAULT_URI\n"
        remote_user="${BASH_REMATCH[1]}"
        remote_host="${BASH_REMATCH[2]}"

cat <<EOF > $remote_kvm_host_inventory
all:
  hosts:
    remote-kvm-host:
      ansible_host: $remote_host
      ansible_user: $remote_user
      ansible_connection: ssh
  children:
    kvm_hosts:
      hosts:
        remote-kvm-host
EOF

        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create Ansible inventory file at $remote_kvm_host_inventory."
            exit 1
        fi      

        ansible all -i $remote_kvm_host_inventory -m ping
        if [ $? -ne 0 ]; then
            error "\nError: Ansible connectivity to remote KVM host failed.\n"
            exit 1
        fi
        success "\nAnsible inventory generated: $remote_kvm_host_inventory\n"
    
    # Generate inventory from local QEMU connection LIBVIRT_DEFAULT_URI
    elif [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        
        info_y "\nINFO: Generating ansible inventory for local KVM host: $LIBVIRT_DEFAULT_URI\n"

cat <<EOF > "$local_kvm_host_inventory"
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_user: $USER
EOF

        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create Ansible inventory file at $local_kvm_host_inventory."
            exit 1
        fi      

        ansible all -i $local_kvm_host_inventory -m ping
        if [ $? -ne 0 ]; then
            error "\nError: Ansible connectivity to remote KVM host failed.\n"
            exit 1
        fi
        success "\nAnsible inventory generated: $local_kvm_host_inventory\n"
    else
        error "\nError: LIBVIRT_DEFAULT_URI is not a valid remote KVM URI.\n"
        exit 1
    fi
}

function user_consent(){
    local inventory_file=$1
    local ansible_host=$2

    IMAGES_STORE=$(yq .IMAGES_STORE inventory/group_vars/all.yml)
    
    info "\nAlert: The Guest images images will be created in:\n"
    info "------------------------------------------------\n"
    # Get Image store related properties
    ansible-inventory -i $inventory_file --host $ansible_host | grep -E "IMAGES_STORE|IMAGE_TEMPLATE_STORE"

    info_y "NOTE: Use ansible host_vars method to overwrite default location.\n"

    pause
}

function install_kvm_host_dependencies(){
    info_y "\nINFO: Installing KVM host dependencies...\n"
    ansible-playbook ansible/hypervisor/install-kvm.yml
    if [[ $? -ne 0 ]]; then
        error "\nERROR: KVM host dependencies installation failed.\n"
        exit 1
    fi
    success "\nSUCCESS: KVM host dependencies installed successfully.\n"
}
