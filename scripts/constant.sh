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
        error "\nERROR: qemu connection is not set\n"
        error "Visit 'QEMU Connection' in 'README.md' for more information\n"
        exit 1
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

