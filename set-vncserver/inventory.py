import os
import fnmatch
import re
import fileinput
import sys
import subprocess


def rsa_key_management(ansible_key_var, inventory_file):
    key_path = re.split('=', ansible_key_var)
    print("Public key in inventory file:", key_path[1].replace('\n', ''))
    ssh_dir = os.path.join(os.environ['HOME'], ".ssh")
    existing_pub_key = os.path.join(ssh_dir, 'id_rsa.pub')

    if os.path.exists(os.path.join(ssh_dir, 'id_rsa.pub')):
        key_update(existing_pub_key, key_path[1].replace('\n', ''), inventory_file)
    else:
        print("Did not find RSA key for {0}".format(str.upper(os.environ['USER'])))
        print("Running playbook sshkey.yaml to generate RSA key for {0}".format(str.upper(os.environ['USER'])))
        subprocess.call(["cd ./generate-ssh-key; ./create-ssh-key.sh"], shell=True)
        key_update(existing_pub_key, key_path[1].replace('\n', ''), inventory_file)


def key_update(current_os_key, current_inventory_key, *argv):
    if current_os_key not in current_inventory_key:
        for change_key in fileinput.input(argv, inplace=1):
            change_key = change_key.replace(current_inventory_key, current_os_key)
            sys.stdout.write(change_key)
        print("Ansible ssh key did match with RSA key. Updated 'ansible_ssh_private_key_file'!!!")
    else:
        print("User already has updated RSA key for 'ansible_ssh_private_key_file', skipping...")


def user_update():
    for files in os.listdir('.'):
        if fnmatch.fnmatch(files, 'inven*.txt'):
            # print(files)
            for line in open(files):
                line = line.strip()
                if line.startswith("ansible_user"):
                    old_user = re.split('=', line)
                    # print("Exising User in file:",  old_user[1].replace('\n', ''))
                    # print(line)
                    if os.environ['USER'] not in line:
                        for change_user in fileinput.input(files, inplace=1):
                            change_user = change_user.replace(old_user[1].replace('\n', ''), os.environ['USER'])
                            sys.stdout.write(change_user)

                elif line.startswith("ansible_ssh_user"):
                    old_user = re.split('=', line)
                    # print("Exising User in file:", old_user[1].replace('\n', ''))
                    if os.environ['USER'] not in line:
                        for change_user in fileinput.input(files, inplace=1):
                            change_user = change_user.replace(old_user[1].replace('\n', ''), os.environ['USER'])
                            sys.stdout.write(change_user)

                elif line.startswith("ansible_ssh_private_key_file"):
                    rsa_key_management(line, files)

                elif line.startswith("ansible_pass"):
                    print("user {0} is using password based authentication!!!".format(str.upper(os.environ['USER'])))


user_update()
