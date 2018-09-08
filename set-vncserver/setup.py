#!/usr/bin/env python

#def check_user():
#    inventory-file = file('inventory.txt')
#    for user in
#    pass
for user_var in "ansible_user", "ansible_ssh_user":
    if user_var in open('inventory.txt'):
        print(user_var)
#if 'condition':
#    pass
#olduser=`cat inventory.txt|egrep ansible_user|cut -d'=' -f2`
#print(olduser)

#pass=`egrep -w "ansible_ssh_pass|ansible_pass" inventory.txt|egrep -v "^#"|wc -l`
#key=`egrep -w "ansible_ssh_private_key_file" inventory.txt|egrep -v "^#"|wc -l`

#if [[ ${key} == 1 ]]; then
#  print

  #statements
#fi
#echo $pass
#echo $key

#if [[ "${olduser}" != ${USER} ]]; then
#  sed -i "s/${olduser}/${USER}/g" inventory.txt
#fi
