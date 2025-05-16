# Connecting to the Hypervisor with virsh Connect

- `qemu:///system` - connects locally as the root user to the daemon supervising guest virtual machines on the KVM hypervisor.
- `qemu:///session` - connects locally as a user to the user's set of guest local machines using the KVM hypervisor.

The command can be run as follows, with the target guest being specified either either by its machine name (hostname) or the URL of the hypervisor (the output of the virsh uri command), as shown:

```bash
$ virsh uri
qemu:///session

# Connect to a remote KVM machine using virsh
$ virsh -c "qemu+ssh://[username]@[hostname/IP]/system"

# The connection URI can also include options for authentication 
$ virsh -c "qemu+ssh://[username]@[hostname/IP]/system?key=[private_key_file]"
```