#!/bin/bash

source scripts/constant.sh

USER_INFRA_ENV_INPUT="scripts/config.yaml"

ROCKY_IMAGE_SOURCE=$(yq .ROCKY_IMAGE_SOURCE $USER_INFRA_ENV_INPUT)
IMAGE_TYPE="qcow2"
IMAGE_TEMPLATE_STORE=$(yq .IMAGE_TEMPLATE_STORE $USER_INFRA_ENV_INPUT)
IMAGES_STORE=$(yq .IMAGES_STORE $USER_INFRA_ENV_INPUT)
: ${SSH_PUB_KEY:="$HOME/.ssh/id_rsa.pub"}

NIC_MODELS="virtio"

# Check provided ssh public key path
[ ! -f $SSH_PUB_KEY ] && error "\nERROR: SSH Public Key $SSH_PUB_KEY not found on localhost\n" && exit 1

# Append variants in VARIANTS from yaml
# virt-install --os-variant list
declare -a VARIANTS=()
for _v in $(yq .VARIANTS[] $USER_INFRA_ENV_INPUT);do
    VARIANTS+=($_v)
done

# Append kvm networks in KVM_NETWORKS from yaml
declare -a KVM_NETWORKS=()
for _n in $(yq .KVM_NETWORKS[] $USER_INFRA_ENV_INPUT);do
    KVM_NETWORKS+=($_n)
done

declare -a IMAGES

# Define the index of default inputs
default_image=0
default_variant=0

: ${VMS_DATA:="$(yq .VMS_DATA $USER_INFRA_ENV_INPUT)"}

# VMS_PURPOSE: Possible app deployment you will do on VMs
declare -a VMS_PURPOSE=()

for _v in $(yq 'keys|.[]' $VMS_DATA);do
    VMS_PURPOSE+=($_v)
done


CLOUD_INIT_INPUT="root-ssh-key=$SSH_PUB_KEY"
#CLOUD_INIT_INPUT="root-password-generate=on"
# #CLOUD_INIT_INPUT="user-data='/home/sumit/Public/dpdk/user-data.yml'"
# #CLOUD_INIT_INPUT="user-data='/home/sumit/Public/dpdk/user-data2.yaml'"
# #CLOUD_INIT_INPUT="root-password-generate=on,user-data='/home/sumit/Public/dpdk/user-data2.yaml'"


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

    sudo cp $image $IMAGE_TEMPLATE_STORE/
    sudo chmod 644 $IMAGE_TEMPLATE_STORE/$image
    success "\nINFO: Image downloaded successfully and copied to image store: $IMAGE_TEMPLATE_STORE\n"
}

function list_images_from_artifactory(){
    for i in $(cd $IMAGE_TEMPLATE_STORE && ls *.qcow2|tr ' ' '\n');do
        IMAGES+=($i)
    done
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
    image_name=$3
	DEST_IMAGE_TYPE="${variant_name}.qcow2"
	VM_ROOT_DISK="${IMAGES_STORE}/${vm}-${DEST_IMAGE_TYPE}"
	if [[ ! -f "${VM_ROOT_DISK}" ]];then
		sudo cp $IMAGE_TEMPLATE_STORE/$image_name $VM_ROOT_DISK
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
    common_name=$5
    MEM=$(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$common_name\").memory" $VMS_DATA)
    VCPU=$(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$common_name\").cpu" $VMS_DATA)
    
    # Set ip_extra_args
    # echo "yq '.${DEPLOYMENT_TYPE}[]|select(.name == \"${vm}\").ip_extra_args' $VMS_DATA" > /tmp/1.sh
    # ip_extra_args=$(source /tmp/1.sh)   
    NICs=$(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$common_name\").nic" $VMS_DATA)
    
    # Ensure NICs and given networks count is matching
    if [[ $NICs != $(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$common_name\").networks|length" $VMS_DATA) ]];then
        error "\nERROR: NICs count: $NICs and Networks length not matching\n"
        exit 1
    fi
        
    # Set interfaces
    network_params=()
    for n in $(yq ".\"$DEPLOYMENT_TYPE\"[]|select(.name == \"$common_name\").networks" $VMS_DATA);do
        if [[ $n =~ ^[a-zA-Z] ]];then
            network_params+=("--network network=$n,model=$NIC_MODELS")
        fi
    done

    info "\n-> Creating $vm with following params..."
    filtered_data "\nDisk: $DISK\nCPU: $VCPU\nMemory: $MEM\nNICs: $NICs\n"
    
    sudo virt-install --name $vm --memory $MEM --vcpu $VCPU --cpu host \
    --boot hd --disk $DISK --import \
    --osinfo detect=on,require=on,name=$VARIANT --noautoconsole \
    ${network_params[@]} \
    --cloud-init $CLOUD_INIT_INPUT
    # --extra-args $ip_extra_args
    if [ $? == 0 ];then
        success "\nINFO: Machine $vm has been created. Waiting for 30 secs to start the machine.\n"
        sleep 30
    else
        error "\nERROR: Failed to create $vm\n"
        exit 1
    fi
}

function create_inventory_file(){
    DEPLOYMENT_TYPE=$1
    INVENTORY_FILE=inventory/$DEPLOYMENT_TYPE-inv
    info "INFO: Creating ansible inventory file: $INVENTORY_FILE for deployment: $DEPLOYMENT_TYPE\n"

cat > $INVENTORY_FILE <<EOF
[all:vars]
ansible_user=root
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
    ansible $vm -i $INVENTORY_FILE -m ping --private-key $SSH_PUB_KEY
}
