### [2025-09-13]
- Added capabilities to download `Ubuntu 22.04` cloud image and build kvm guest machines.
- Added capabilities to create KV networks. Review "Create Additional KVM Networks" section for more information.

## [2025-09-16]
- Add multiple interfaces in guest machine during image build.
- Improved cloud-init implementation to configure dhcp ips on all interfaces.
- Improved cloud-init to configure sshd config.
- FIX ME: Generate inventory using `./setup.sh -g` option.