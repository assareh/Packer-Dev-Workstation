# Disposable Development VM for VMware Fusion

This Packer configuration builds an Ubuntu 24.04 LTS OVA optimized as a disposable development virtual machine for VMware Fusion. The VM is designed to provide an isolated environment where you can run potentially flawed code without risking access to credentials and secrets on your primary machine.

## Features

- Ubuntu 24.04 LTS Server (minimal installation)
- Git pre-installed and configured
- Python 3.12+ with pip and common development tools
- Claude Code CLI pre-installed
- VMware Tools for seamless integration with VMware Fusion
- SSH server configured for VS Code Remote SSH access
- Optimized for development workloads
- Clean, minimal footprint

## Prerequisites

- [Packer](https://www.packer.io/downloads) (latest version recommended)
- [VMware Fusion](https://www.vmware.com/products/fusion.html) on macOS
- At least 500GB of free disk space for the build
- Internet connection for downloading ISO and packages

## Quick Start

1. **Clone or download this repository**

2. **Initialize Packer plugins:**
   ```bash
   packer init .
   ```

3. **Build the OVA:**
   ```bash
   packer build ubuntu-dev.pkr.hcl
   ```

4. **Import the OVA into VMware Fusion:**
   - Open VMware Fusion
   - Go to File > Import
   - Select the generated OVA file (in the `output-ubuntu-dev-vm` directory)
   - Follow the import wizard

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
- **Version Control:** Git
- **Python:** Python 3.12+ with pip
- **Python Tools:** virtualenv, pylint, black, pytest, ipython
- **Development:** build-essential (gcc, make, etc.)
- **Claude AI:** Claude Code CLI
- **VMware:** open-vm-tools for better integration

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
3. Installs base system and VMware tools
4. Runs provisioning scripts to install Git, Python, and Claude Code
5. Cleans up temporary files and logs
6. Exports as an OVA file

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
