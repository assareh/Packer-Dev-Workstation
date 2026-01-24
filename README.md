# Disposable Development VM

This Packer configuration builds an Ubuntu 24.04 LTS virtual machine optimized as a disposable development environment. The VM is designed to provide an isolated environment where you can run potentially flawed code without risking access to credentials and secrets on your primary machine.

**Supports two deployment targets:**
- **VMware Fusion** (Mac mini / macOS) - OVA format
- **QEMU/KVM** (Nomad host / Linux) - QCOW2 format

## Features

- Ubuntu 24.04 LTS Server (minimal installation)
- Git pre-installed and configured
- Python 3.12+ with pip and common development tools
- Claude Code CLI pre-installed
- Hypervisor-specific guest tools (VMware Tools or QEMU Guest Agent)
- SSH server configured for VS Code Remote SSH access
- Tailscale for easy VPN/Tailnet connectivity
- Optimized for development workloads
- Clean, minimal footprint

## Prerequisites

- [Packer](https://www.packer.io/downloads) (latest version recommended)
- At least 500GB of free disk space for the build
- Internet connection for downloading ISO and packages

**For VMware Fusion (Mac mini):**
- [VMware Fusion](https://www.vmware.com/products/fusion.html) on macOS

**For QEMU/KVM (Nomad host / Linux):**
- QEMU/KVM installed (`sudo apt install qemu-kvm libvirt-daemon-system`)
- User in kvm group (`sudo usermod -aG kvm $USER`)

## Quick Start

1. **Clone or download this repository**

2. **Initialize Packer plugins:**
   ```bash
   packer init .
   ```

3. **Build for your target platform:**

   **Option A: VMware Fusion (Mac mini)**
   ```bash
   packer build ubuntu-dev.pkr.hcl
   ```
   Then import the OVA from `output-ubuntu-dev-vm/` into VMware Fusion.

   **Option B: QEMU/KVM (Nomad host / Linux)**
   ```bash
   packer build -var 'builder=qemu' ubuntu-dev.pkr.hcl
   ```
   The QCOW2 image will be in `output-ubuntu-dev-vm-qemu/`.

4. **Deploy the VM:**

   **VMware Fusion:**
   - Open VMware Fusion > File > Import
   - Select the generated OVA file
   - Follow the import wizard

   **QEMU (standalone):**
   ```bash
   ./scripts/run-qemu-vm.sh
   ```

   **Nomad cluster:**
   ```bash
   # First upload the QCOW2 to an accessible location, then:
   nomad job run -var 'image_url=https://your-storage/ubuntu-dev-vm.qcow2' nomad/dev-workstation.nomad.hcl
   ```

## Recovery Scenarios

This configuration supports two recovery targets for your development workstation:

### Option 1: Mac mini with VMware Fusion
- **Specs:** 12 cores, VMware Fusion installed
- **Pros:** Native VMware support, easy OVA import
- **Build:** `packer build ubuntu-dev.pkr.hcl`
- **Deploy:** Import OVA into VMware Fusion

### Option 2: Nomad Host with QEMU/KVM
- **Specs:** 64GB RAM, 8 cores, 300 Mb fiber
- **Pros:** Faster network, more RAM, orchestrated deployment
- **Build:** `packer build -var 'builder=qemu' ubuntu-dev.pkr.hcl`
- **Deploy:** Via Nomad job or standalone QEMU script

### Tailscale Integration

Both options include Tailscale pre-installed. After booting the VM:

```bash
sudo tailscale up
```

This connects the VM to your Tailnet for easy remote access regardless of which host runs it.

## Customization

To customize the VM configuration, copy the example variables file and modify it:

```bash
cp variables.pkrvars.hcl.example variables.pkrvars.hcl
```

Edit `variables.pkrvars.hcl` to change:
- VM name
- SSH credentials
- CPU count
- Memory allocation
- Disk size
- Builder type (`vmware` or `qemu`)
- QEMU accelerator (`kvm`, `hvf`, or `tcg`)

Then build with your custom variables:

```bash
packer build -var-file=variables.pkrvars.hcl ubuntu-dev.pkr.hcl
```

## Default Credentials

- **Username:** `developer`
- **Password:** `developer`

**IMPORTANT:** Change these credentials if you plan to expose the VM to any network other than a trusted local network.

## Connecting with VS Code Remote SSH

1. **Get the VM's IP address:**
   After starting the VM, log in and run:
   ```bash
   ip addr show
   ```

2. **Configure SSH in VS Code:**
   - Install the "Remote - SSH" extension in VS Code
   - Press `Cmd+Shift+P` and select "Remote-SSH: Connect to Host"
   - Enter: `developer@<VM_IP_ADDRESS>`
   - Enter the password when prompted

3. **Start developing:**
   - Your workspace directory is at `/home/developer/workspace`
   - Claude Code is available via the `claude` command
   - All your Python development tools are pre-installed

## First Boot Setup

When you first boot the VM, it will automatically:

1. **Generate a new SSH key pair** specifically for this VM
2. **Display the public key** in the message of the day (MOTD)
3. **Configure Git** to work with GitHub Personal Access Tokens (PAT)

### GitHub Configuration

1. **Add SSH key to GitHub:**
   - After first login, the SSH public key will be displayed
   - Copy it and add to your GitHub account: https://github.com/settings/ssh/new
   - Or run: `./show-ssh-key.sh` to see it again

2. **Set up your GitHub PAT:**
   - Create a new PAT at: https://github.com/settings/tokens
   - Recommended: Use a **fine-grained token** with only repository access
   - When you first `git push`, Git will prompt for credentials:
     - Username: your GitHub username
     - Password: paste your PAT (not your GitHub password!)
   - Git will store this securely for future operations

3. **Test your connection:**
   ```bash
   ssh -T git@github.com
   ```

### Why Separate Credentials?

This VM is designed for running AI coding assistants that may execute arbitrary code. Using separate SSH keys and a limited-scope PAT provides isolation from your main development credentials.

## Installed Software

- **Base:** Ubuntu 24.04 LTS Server
- **Version Control:** Git, GitHub CLI
- **Python:** Python 3.12+ with pip
- **Python Tools:** virtualenv, pylint, black, pytest, ipython
- **Node.js:** LTS version with npm
- **Development:** build-essential (gcc, make, etc.)
- **AI Assistants:** Claude Code CLI, OpenAI Codex CLI, Google Gemini CLI
- **Cloud CLIs:** AWS CLI, Azure CLI, Google Cloud SDK
- **Infrastructure:** Terraform
- **Networking:** Tailscale (run `sudo tailscale up` after boot to connect)
- **Guest Tools:** open-vm-tools (VMware) or qemu-guest-agent (QEMU)

## Security Considerations

This VM is designed for **isolated development of untrusted code**:

- Run potentially flawed or experimental code without risking your host system
- No access to your host machine's credentials or secrets
- Easily disposable - just delete and recreate from the OVA
- SSH password authentication enabled for convenience (disable if exposing to networks)
- Root login via SSH is disabled
- Unique SSH keys generated automatically on first boot
- Git configured for PAT-based authentication (no hardcoded credentials)

### Best Practices:

1. **Use a fine-grained GitHub PAT** with minimal repository permissions
2. **Don't store sensitive data** in this VM - it's meant to be disposable
3. **Snapshot before risky operations** - VMware Fusion makes this easy
4. **Take a "clean baseline" snapshot** after first boot and GitHub setup
5. **Destroy and recreate regularly** to ensure a clean environment
6. **Keep the VM on a NAT or Host-Only network** to limit exposure
7. **Monitor what AI assistants are doing** - they have full system access!

## Build Process

The Packer build process:

1. Downloads Ubuntu 24.04 LTS ISO
2. Boots the ISO and automates installation using cloud-init
3. Installs base system and hypervisor-specific guest tools
4. Runs provisioning scripts to install development tools
5. Cleans up temporary files and logs
6. Exports as OVA (VMware) or QCOW2 (QEMU)

**Output locations:**
- VMware: `output-ubuntu-dev-vm/ubuntu-dev-vm.ova`
- QEMU: `output-ubuntu-dev-vm-qemu/ubuntu-dev-vm`

Total build time: ~20-30 minutes (depending on internet speed and host performance)

## Troubleshooting

### Build fails with "connection timeout"
- Increase `ssh_timeout` in `ubuntu-dev.pkr.hcl`
- Check your internet connection

### VM doesn't get an IP address
- Ensure VMware Fusion NAT networking is enabled
- Check VMware Fusion preferences > Network

### Can't connect via SSH
- Verify the VM has network connectivity: `ip addr show`
- Check SSH service is running: `sudo systemctl status ssh`
- Ensure no firewall is blocking port 22

### Claude Code not found
- The install script runs during provisioning
- Check `/var/log/cloud-init-output.log` for errors
- Manually install: `curl -fsSL https://claude.ai/install.sh | sh`

## Maintenance

### Updating the base image:

To get the latest Ubuntu updates:

```bash
sudo apt update
sudo apt upgrade -y
```

### Creating a new clean VM:

Simply import the OVA again - each import creates a fresh, isolated instance.

## License

This configuration is provided as-is for your use. Feel free to modify as needed.

## Contributing

Suggestions and improvements are welcome! This is a starting point - customize it for your specific development needs.
