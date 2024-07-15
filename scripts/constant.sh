#!/bin/bash

ROCKY_IMAGE_SOURCE="https://dl.rockylinux.org/pub/rocky/9/images/x86_64"
IMAGE_TYPE="qcow2"
IMAGES_STORE="/var/lib/libvirt/images"
PRIVATE_KEY="/home/sumit/.ssh/id_rsa.pub"

declare -a NIC_MODELS=(
    "virtio"
)

# virt-install --os-variant list
declare -a VARIANTS=(
    "rocky9"
    "centos-stream9"
    
)

declare -a IMAGES=(
    "rocky9-template"
	"Rocky-9-GenericCloud-LVM.latest.x86_64"
	"Rocky-9-GenericCloud-LVM-9.4-20240609.0.x86_64"
)

declare -a VMS_PURPOSE=(
    "custom"
    "openstack"
)

declare -a KVM_NETWORKS=(
    "default"
    "tenant"
)

# Define the index of default inputs
default_image=0
default_variant=0
default_deployment=0

VMS_DATA="data.yaml"

# Color variables
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
magenta='\033[0;35m'
cyan='\033[0;36m'
# Clear the color after that
clear='\033[0m'

CLOUD_INIT_INPUT="root-ssh-key=$PRIVATE_KEY"
#CLOUD_INIT_INPUT="root-password-generate=on"
# CLOUD_INIT_INPUT="root-ssh-key=/home/sumit/.ssh/id_rsa.pub"
# #CLOUD_INIT_INPUT="user-data='/home/sumit/Public/dpdk/user-data.yml'"
# #CLOUD_INIT_INPUT="user-data='/home/sumit/Public/dpdk/user-data2.yaml'"
# #CLOUD_INIT_INPUT="root-password-generate=on,user-data='/home/sumit/Public/dpdk/user-data2.yaml'"

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

function list_images(){
	for i in ${!IMAGES[@]};do
		echo "$i. ${IMAGES[$i]}"
	done
}

function list_variant(){
	for i in ${!VARIANTS[@]};do
		echo "$i. ${VARIANTS[$i]}"
	done
}

function list_vms_purpose(){
	for i in ${!VMS_PURPOSE[@]};do
		echo "$i. ${VMS_PURPOSE[$i]}"
	done
}

function download_image(){
    image=$1
    if echo $image|grep -Eq ^Rocky;then
        image_download_url=$ROCKY_IMAGE_SOURCE/$image
    fi
    info "\nINFO: Downloading image: $image_download_url\n"
    wget -q $image_download_url

    sudo cp $image $IMAGES_STORE/
    sudo chmod 644 $IMAGES_STORE/$image
    success "\nINFO: Image downloaded successfully and copied to image store: $IMAGES_STORE\n"
}

# function vm_disk_cleanup(){
#     vm=$1
#     vm_disk=$2
#     if ! sudo virsh dominfo $vm > /dev/null 2>&1;then
#         info "\n -> VM: $vm not found, do you wish to remove disk: $vm_disk...\n"
#         read -p "Choice [y/N]: " _disk_remove
#         if [ "${_disk_remove,,}" == "y" ] || [ "${_disk_remove,,}" == "yes" ];then
#             sudo rm -f $vm_disk
#             success "\n-> Removed virtual disk: $vm_disk\n"
#         elif [ "${_disk_remove,,}" == "n" ] || [ "${_disk_remove,,}" == "no" ];then
#             info "\n-> Skipped disk cleanup for $vm_disk\n"
#         else
#             error "\nERROR: Invalid Input. Exiting...\n"
#             exit 1
#         fi
# }

function vm_disks(){
	vm=$1
	variant_name=$2
	DEST_IMAGE_TYPE="${variant_name}.qcow2"
	VM_ROOT_DISK="${IMAGES_STORE}/${vm}-${DEST_IMAGE_TYPE}"
	if [[ ! -f "${VM_ROOT_DISK}" ]];then
		sudo cp $IMAGES_STORE/$image_full_name $VM_ROOT_DISK
		sudo chmod 644 $VM_ROOT_DISK
		success "\nCreated VM Disk: $VM_ROOT_DISK"
    else
        success "\n-> Root disk: $VM_ROOT_DISK already exists for VM: $vm"
	fi
}

function vm_install(){
    vm=$1
    DISK=$2
    VARIANT=$3
    DEPLOYMENT_TYPE=$4
    MEM=$(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$vm\").memory" $VMS_DATA)
    VCPU=$(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$vm\").cpu" $VMS_DATA)
    
    # Set ip_extra_args
    # echo "yq '.${DEPLOYMENT_TYPE}[]|select(.name == \"${vm}\").ip_extra_args' $VMS_DATA" > /tmp/1.sh
    # ip_extra_args=$(source /tmp/1.sh)   
    NICs=$(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$vm\").nic" $VMS_DATA)
    
    # Ensure NICs and given networks count is matching
    if [[ $NICs != $(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$vm\").networks|length" $VMS_DATA) ]];then
        error "\nERROR: NICs count: $NICs and Networks length not matching\n"
        exit 1
    fi
        
    # Set interfaces
    network_params=()
    for n in $(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$vm\").networks" $VMS_DATA);do
        if [[ $n =~ ^[a-zA-Z] ]];then
            network_params+=("--network network=$n,model=${NIC_MODELS[0]}")
        fi
    done

    info "\n-> Creating $vm with following params..."
    filtered_data "\nDisk: $DISK\nCPU: $VCPU\nMemory: $MEM\nNICs: $NICs\n"

    if ! sudo virsh dominfo $vm > /dev/null 2>&1;then
        sudo virt-install --name $vm --memory $MEM --vcpu $VCPU --cpu host \
        --boot hd --disk $DISK --import \
        --osinfo detect=on,require=on,name=$VARIANT --noautoconsole \
        --cloud-init $CLOUD_INIT_INPUT \
        ${network_params[@]}
        # --network network="${KVM_NETWORKS[0]}",model=virtio --network network="${KVM_NETWORKS[1]}",model=virtio
        # --extra-args $ip_extra_args
        sleep 30
    else
        success "\n-> VM $vm is already exists.\n"
    fi
}

function create_inventory_file(){
    DEPLOYMENT_TYPE=$1
    INVENTORY_FILE=inventory/$DEPLOYMENT_TYPE-inv
    info "INFO: Creating ansible inventory file: $INVENTORY_FILE for deployment: $DEPLOYMENT_TYPE\n"

cat > $INVENTORY_FILE <<EOF
[all:vars]
ansible_user=root
# ansible_private_key=$PRIVATE_KEY
ansible_password=redhat
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOF
}
function get_vm_ips(){
    vm=$1
    vm_ips=$(sudo virsh domifaddr $vm|awk '/vnet/{print $4}'|cut -d'/' -f1|xargs)
}

function vm_ansible_test(){
    vm=$1
    info "INFO: Running ansible ping test...\n"
    ansible $vm -i $INVENTORY_FILE -m ping --private-key $PRIVATE_KEY
}
