#!/bin/bash

function assert_python3_installed(){
    if ! command -v python3 &> /dev/null; then
        error "python3 could not be found. Please install python3."
        # pause
        install_python3
    fi
}

function assert_ansible_core(){
    if ! command -v ansible-playbook &> /dev/null; then
        error "ansible-playbook could not be found. Please install Ansible."
        # pause
        install_ansible
    fi
}

function assert_yq_installed(){
    if ! command -v yq &> /dev/null; then
        error "yq could not be found. Please install yq."
        # pause
        install_yq
    fi
}

function assert_ansible_collections(){
    if ! ansible-galaxy collection list | grep 'community.general' > /dev/null; then
        info_y "Ansible collection community.general not found. Installing..."
        for collection in $(yq eval '.collections[]|.name' scripts/requirements.yml);do
            ansible-galaxy collection install $collection
            if [ $? -ne 0 ]; then
                error "Failed to install Ansible collections. Please check your internet connection and try again."
                exit 1
            fi
        done
    fi    
}

function assert_ssh_keygen_installed(){
    if ! command -v ssh-keygen &> /dev/null; then
        error "ssh-keygen could not be found. Please install OpenSSH."
        # pause
        install_openssh
    fi
}

function assert_virsh_installed(){
    if ! command -v virsh &> /dev/null; then
        error "virsh could not be found. Please install libvirt."
        # pause
        install_virsh
    fi
}

function assert_libvirt_uri_connection(){
    if [ -z $LIBVIRT_DEFAULT_URI ]; then
        error "Please set LIBVIRT_DEFAULT_URI environment variable for QEMU connection."
        # pause
        set_virsh_connection
    fi
}

function set_virsh_cli(){
    VIRSH_CMD="virsh --connect $LIBVIRT_DEFAULT_URI"
    info "Using virsh command: $VIRSH_CMD"
    pause
}

function assert_remote_kvm_for_ssh(){
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/(root|[a-zA-Z0-9]+)@.+\/system ]]; then
        # Run block when kvm connection to remote machine
        # Check if the user has passwordless sudo privileges for virsh
        username=$(echo $LIBVIRT_DEFAULT_URI | sed -E 's/^qemu\+ssh:\/\/([^@]+)@.+\/system$/\1/')
        kvm_host=$(echo $LIBVIRT_DEFAULT_URI | sed -E 's/^qemu\+ssh:\/\/[^@]+@(.+)\/system$/\1/')
        
        info "INFO: Checking SSH connection for remote KVM host: $kvm_host with user: $username\n"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $username@$kvm_host 'exit' &> /dev/null; then
            error "\nCannot reach remote KVM host $kvm_host over SSH with passwordless authentication. Please check your connection and try again.\n"
            copy_rsa_ssh_key_to_remote_kvm $username $kvm_host
        fi

        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $username@$kvm_host 'sudo whoami' &> /dev/null; then
            error "\nYou do not have passwordless sudo privileges for virsh on remote host $kvm_host. Please set up passwordless sudo for virsh.\n"
            exit 1
        fi
    fi
}

function assert_remote_kvm_for_virsh(){
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/(root|[a-zA-Z0-9]+)@.+\/system ]]; then
        # Run block when kvm connection to remote machine
        # Check if the user has passwordless sudo privileges for virsh
        username=$(echo $LIBVIRT_DEFAULT_URI | sed -E 's/^qemu\+ssh:\/\/([^@]+)@.+\/system$/\1/')
        kvm_host=$(echo $LIBVIRT_DEFAULT_URI | sed -E 's/^qemu\+ssh:\/\/[^@]+@(.+)\/system$/\1/')
        
        if [[ $username != "root" ]]; then
            error "\nRemote KVM connection must use root user. Current user: $username\n"
            exit 1
        fi

        info "INFO: Checking SSH connection for virsh command on remote KVM host: $kvm_host with user: $username\n"
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $username@$kvm_host 'command -v virsh' &> /dev/null; then
            error "\nvirsh command not found on remote KVM host $kvm_host. Please check.\n"
            exit 1
        fi

        # Test actual virsh connection to detect polkit authentication issues
        if ! ssh -o BatchMode=yes -o ConnectTimeout=5 $username@$kvm_host 'virsh --connect qemu:///system list' &> /dev/null; then
            if ssh -o BatchMode=yes -o ConnectTimeout=5 $username@$kvm_host 'virsh --connect qemu:///system list' 2>&1 | grep -q 'polkit\|authentication unavailable'; then
                error "\n❌ Authentication error: polkit agent not available on remote host.\n"
                info_y "Solutions:\n"
                info_y "1. Connect as root user (recommended):\n"
                info_y "   export LIBVIRT_DEFAULT_URI=\"qemu+ssh://root@$kvm_host/system\"\n\n"
                info_y "2. Or configure sudoers on remote host to allow libvirt commands without password:\n"
                info_y "   On $kvm_host, add to /etc/sudoers.d/libvirt-sudoers:\n"
                info_y "   $username ALL=(ALL) NOPASSWD: /usr/bin/virsh\n"
                exit 1
            fi
        fi
    fi
}