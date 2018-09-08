import os
import fnmatch
import re
import fileinput
import sys
import subprocess

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
                    key_path = re.split('=', line)
                    # print("Exising ssh private key:", key_path[1].replace('\n', ''))
                    ssh_dir = os.path.join(os.environ['HOME'], ".ssh")
                    # print(ssh_dir)
                    for ssh_key in os.listdir(ssh_dir):
                        if fnmatch.fnmatch(ssh_key, 'id_rsa.pub'):
                            new_key_path = os.path.join(ssh_dir, ssh_key)
                            if new_key_path not in line:
                                for change_key in fileinput.input(files, inplace=1):
                                    change_key = change_key.replace(key_path[1].replace('\n', ''), new_key_path)
                                    sys.stdout.write(change_key)
                        else:
                            subprocess.call(["cd ./generate-ssh-key; ./create-ssh-key.sh"], shell=True)

                elif line.startswith("ansible_pass"):
                    print("user {0} is using password based authentication!!!".format(str.upper(os.environ['USER'])))



user_update()


