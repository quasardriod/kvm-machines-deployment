#!/usr/bin/env bash

olduser=`cat inventory.txt|egrep ansible_user|cut -d'=' -f2`

pass=`egrep -w "ansible_ssh_pass|ansible_pass" inventory.txt|egrep -v "^#"|wc -l`
key=`egrep -w "ansible_ssh_private_key_file" inventory.txt|egrep -v "^#"|wc -l`

if [[ ${key} == 1 ]]; then
  print

  #statements
fi
echo $pass
echo $key

#if [[ "${olduser}" != ${USER} ]]; then
#  sed -i "s/${olduser}/${USER}/g" inventory.txt
#fi
