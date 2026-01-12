#!/bin/bash

# Set -eo pipefail
# set -e: Exit immediately if a command exits with a non-zero status.
# set -o pipefail: This option causes a pipeline to return the exit status of the last command in the pipeline that failed, or zero if no command failed.
# set -eo pipefail

libvirt_default_uri_file=/tmp/libvirt_default_uri.txt
tmp_inventory_file=/tmp/kvm-host-inventory.ini
inventory_file=inventory/kvm-host-inventory.ini

function pause(){
    echo
    read -p "Enter to continue or Ctrl+C to cancel: " dummy_variable
}

function install_virsh(){
    info_y "\nINFO: Installing libvirt on the system...\n"
    
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y libvirt-clients libvirt-daemon-system
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y libvirt
    else
        error "\nERROR: Unsupported package manager. Please install libvirt manually.\n"
        exit 1
    fi

    if [[ $? -ne 0 ]]; then
        error "\nERROR: libvirt installation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: libvirt installed successfully.\n"
}

function install_python3(){
    info_y "\nINFO: Installing python3 and python3-pip on the system...\n"
    
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y python3 python3-pip
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 python3-pip
    else
        error "\nERROR: Unsupported package manager. Please install python3 and python3-pip manually.\n"
        exit 1
    fi

    if [[ $? -ne 0 ]]; then
        error "\nERROR: Python3 and pip installation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: Python3 and pip installed successfully.\n"
}

function install_ansible_userspace(){
    info_y "\nINFO: Installing Ansible using pip...\n"
    
    pip3 install --user ansible

    if [[ $? -ne 0 ]]; then
        error "\nERROR: Ansible installation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: Ansible installed successfully.\n"
}

function install_ansible(){
    info_y "\nINFO: Installing Ansible on the system...\n"
    
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y ansible-core
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ansible-core
    else
        error "\nERROR: Unsupported package manager. Please install Ansible manually.\n"
        exit 1
    fi

    if [[ $? -ne 0 ]]; then
        error "\nERROR: Ansible installation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: Ansible installed successfully.\n"
}

function install_yq(){
    info_y "\nINFO: Installing yq on the system...\n"
    
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y yq
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y yq
    else
        error "\nERROR: Unsupported package manager. Please install yq manually.\n"
        exit 1
    fi

    if [[ $? -ne 0 ]]; then
        error "\nERROR: yq installation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: yq installed successfully.\n"
}

function install_openssh(){
    info_y "\nINFO: Installing OpenSSH on the system...\n"
    
    if command -v apt &> /dev/null; then
        sudo apt update
        sudo apt install -y openssh-client
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y openssh-clients
    else
        error "\nERROR: Unsupported package manager. Please install OpenSSH manually.\n"
        exit 1
    fi

    if [[ $? -ne 0 ]]; then
        error "\nERROR: OpenSSH installation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: OpenSSH installed successfully.\n"
}

function allow_passwordless_sudo_for_virsh(){
    local user_name=$1

    info_y "\nINFO: Allowing passwordless sudo for user: $user_name to run virsh command...\n"
    info_y "------------------------------------------------\n"
    info_y "Adding the following line to /etc/sudoers.d/90-$user_name-virsh:\n"
    info_y "$user_name ALL=(ALL) NOPASSWD: /usr/bin/virsh\n"
    pause
}

# Configure virsh connection
function set_virsh_connection(){
    # Check if libvirt is installed
    if [ ! -f $libvirt_default_uri_file ]; then
        info_y "\nINFO: libvirt_default_uri_file not found.\n"
    else
        info_y "\nINFO: Reading LIBVIRT_DEFAULT_URI from $libvirt_default_uri_file\n"
        export LIBVIRT_DEFAULT_URI=$(cat $libvirt_default_uri_file)
    fi

    if [[ -z $LIBVIRT_DEFAULT_URI ]]; then
        read -r -p "Do you wish to set it now? [y/N]: " consent
        if [[ ${consent,,} == "y" ]] || [[ ${consent,,} == "yes" ]];then
            info_y "\nINFO: Please provide the QEMU connection string:\n"
            info_y "------------------------------------------------\n"
            info_y "For local KVM host: export LIBVIRT_DEFAULT_URI='qemu:///system'\n"
            info_y "For remote KVM host: export LIBVIRT_DEFAULT_URI='qemu+ssh://root@<remote-kvm-host>/system'\n"
            info_y "------------------------------------------------\n"
            read -p "LIBVIRT_DEFAULT_URI: " LIBVIRT_DEFAULT_URI
            
            echo $LIBVIRT_DEFAULT_URI > $libvirt_default_uri_file
            export LIBVIRT_DEFAULT_URI=$(cat $libvirt_default_uri_file)

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

    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh:\/\/(root|[a-zA-Z0-9]+)@.+\/system ]]; then
        # Run block when kvm connection to remote machine
        # Check if the user has passwordless sudo privileges for virsh
        assert_remote_kvm_for_ssh
        export VIRSH_CMD="virsh --connect $LIBVIRT_DEFAULT_URI"
    fi
    info_y "INFO: Using virsh command: $VIRSH_CMD\n"
}

function create_ssh_keygen(){
    info_y "\nINFO: Generating SSH key pair for passwordless SSH access to remote KVM host...\n"
    
    ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N ""

    if [[ $? -ne 0 ]]; then
        error "\nERROR: SSH key pair generation failed.\n"
        exit 1
    fi

    success "\nSUCCESS: SSH key pair generated successfully.\n"
}

function copy_rsa_ssh_key_to_remote_kvm(){
    local remote_user=$1
    local remote_host=$2

    info_y "\nINFO: Copying SSH public key to remote KVM host: $remote_user@$remote_host\n"
    pause
    
    ssh-copy-id -i ~/.ssh/id_rsa.pub "$remote_user@$remote_host"

    if [[ $? -ne 0 ]]; then
        error "\nERROR: Copying SSH public key to remote KVM host failed.\n"
        exit 1
    fi

    success "\nSUCCESS: SSH public key copied to remote KVM host successfully.\n"
}

# Generate ansible inventory for remote KVM host on the fly
function generate_kvm_host_inventory(){
    # https://www.bashsupport.com/bash/variables/bash_rematch/

    # Generate inventory from remote QEMU connection LIBVIRT_DEFAULT_URI
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh://([^@]+)@([^/]+)/system$ ]]; then

        info_y "\nINFO: Generating ansible inventory for remote KVM host: $LIBVIRT_DEFAULT_URI\n"
        kvm_user="${BASH_REMATCH[1]}"
        kvm_host="${BASH_REMATCH[2]}"
    elif [[ $LIBVIRT_DEFAULT_URI =~ ^qemu:///system$ ]]; then
        info_y "\nINFO: Generating ansible inventory for local KVM host: $LIBVIRT_DEFAULT_URI\n"
        kvm_user=$USER
        kvm_host=localhost
    else
        error "\nERROR: LIBVIRT_DEFAULT_URI is not a valid remote KVM URI.\n"
        exit 1
    fi
    
    if [ -f $tmp_inventory_file ]; then
        info_y "\nINFO: Removing existing inventory file: $tmp_inventory_file\n"
        rm -f $tmp_inventory_file
    fi
    
    if [ $kvm_user != "root" ];then
        escalate_previliges="yes"
    else
        escalate_previliges="no"
    fi
    ansible localhost -m template --args "src=scripts/inventory.j2 dest=$tmp_inventory_file" \
        -e kvm_user="$kvm_user" \
        -e kvm_host="$kvm_host" \
        -e escalate_previliges="$escalate_previliges" \
        --connection=local


    if [[ $? -ne 0 ]]; then
        error "\nError: Failed to create Ansible inventory file at $tmp_inventory_file.\n"
        exit 1
    fi      

    ansible all -i $tmp_inventory_file -m ping
    if [ $? -ne 0 ]; then
        error "\nError: Ansible connectivity to remote KVM host failed.\n"
        exit 1
    fi
    cp $tmp_inventory_file $inventory_file
    success "\nAnsible inventory generated: $inventory_file\n"
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

function set_kvm_host_inventory(){
    if [[ $LIBVIRT_DEFAULT_URI =~ ^qemu\+ssh://([^@]+)@([^/]+)/system$ ]]; then
        export KVM_HOST_INVENTORY="$remote_kvm_host_inventory"
        export KVM_HOST_ANSIBLE_NAME="remote-kvm-host"
    elif [[ $LIBVIRT_DEFAULT_URI =~ ^^qemu:\/\/\/system$ ]]; then
        export KVM_HOST_INVENTORY="$local_kvm_host_inventory"
        export KVM_HOST_ANSIBLE_NAME="localhost"
    else
        error "\nERROR: LIBVIRT_DEFAULT_URI is not set properly for KVM host inventory.\n"
        exit 1
    fi
    info_y "\nINFO: KVM Host Ansible Inventory: $KVM_HOST_INVENTORY\n"
    info_y "INFO: KVM Host Ansible Name: $KVM_HOST_ANSIBLE_NAME\n"
}

function install_kvm_host_dependencies(){
    generate_kvm_host_inventory
    info_y "\nINFO: Installing KVM host dependencies...\n"
    ansible-playbook -i $inventory_file ansible/hypervisor/install-kvm.yml
    if [[ $? -ne 0 ]]; then
        error "\nERROR: KVM host dependencies installation failed.\n"
        exit 1
    fi
    success "\nSUCCESS: KVM host dependencies installed successfully.\n"
}
