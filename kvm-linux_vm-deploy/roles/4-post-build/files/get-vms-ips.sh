#!/usr/bin/env bash

if [ -f /var/tmp/kube-vms-inventory.yml ]; then
  rm -rf /var/tmp/kube-vms-inventory.yml
fi

for vm in `virsh list|grep -i kube|awk '{print $2}'`;do
  get_eth=`virsh domiflist $vm|grep -i virtio|awk '{print $1}'`
  get_mac=`virsh domiflist $vm|grep -i virtio|awk '{print $5}'`
  tcpdump -e -i $get_eth -G 30 -W 1 -w $vm.pcap
  tcpdump -r $vm.pcap|egrep -w "is-at $get_mac"
  if [ $? == 0 ];then
    got_ip=`tcpdump -r $vm.pcap|egrep -w "is-at $get_mac"|grep -o -P '(?<=Reply).*(?=is-at)'|head -1|xargs`
    echo "${vm} ansible_ssh_host=$got_ip" >> /var/tmp/kube-vms-inventory.yml
    rm -rf $vm.pcap
  fi
done
echo "" >> /var/tmp/kube-vms-inventory.yml
echo "[all:vars]" >> /var/tmp/kube-vms-inventory.yml
echo "ansible_ssh_user=stack" >> /var/tmp/kube-vms-inventory.yml
echo "ansible_ssh_pass=redhat" >> /var/tmp/kube-vms-inventory.yml
