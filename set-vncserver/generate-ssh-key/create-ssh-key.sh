#!/bin/bash

get_user=`grep -i user local-user.yaml|cut -d':' -f2`
if [ ${get_user} != ${USER} ]
then
	echo "user: ${USER}" > local-user.yaml
fi

ansible-playbook -i local-inventory.txt sshkey.yaml
