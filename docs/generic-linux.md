1. Created hashed password to use in cloud-init
```bash
echo 'yourpass' | mkpasswd -m sha-512 -s
```