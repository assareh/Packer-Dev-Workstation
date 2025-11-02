#!/bin/bash
# First boot setup script - generates SSH keys and configures Git
# This runs once on the first boot of the VM

set -e

MARKER_FILE="/home/developer/.first-boot-complete"

# Check if already run
if [ -f "$MARKER_FILE" ]; then
    exit 0
fi

echo "Running first-boot setup..."

# Generate SSH key for GitHub
if [ ! -f /home/developer/.ssh/id_ed25519 ]; then
    echo "Generating SSH key for GitHub..."
    sudo -u developer ssh-keygen -t ed25519 -C "dev-vm@disposable" -f /home/developer/.ssh/id_ed25519 -N ""

    # Start ssh-agent and add key
    sudo -u developer bash -c 'eval "$(ssh-agent -s)" && ssh-add /home/developer/.ssh/id_ed25519'
fi

# Configure Git for PAT usage
sudo -u developer git config --global credential.helper store
sudo -u developer git config --global user.name "Dev VM"
sudo -u developer git config --global user.email "devvm@disposable.local"

# Create a welcome message with the SSH public key
cat > /etc/motd << 'EOF'
================================================================================
  Welcome to your Disposable Development VM!

  This VM is configured for running AI coding assistants safely.
================================================================================

SETUP REQUIRED:
1. Add this SSH public key to your GitHub account:

EOF

cat /home/developer/.ssh/id_ed25519.pub >> /etc/motd

cat >> /etc/motd << 'EOF'

2. Configure Git with your GitHub Personal Access Token (PAT):

   First time you push, Git will prompt for credentials:
   - Username: your-github-username
   - Password: your-personal-access-token (not your password!)

   The PAT will be stored securely for future use.

3. Create a snapshot of this clean state before starting work!

================================================================================

Useful commands:
  - View this SSH key again: cat ~/.ssh/id_ed25519.pub
  - Test GitHub connection: ssh -T git@github.com
  - Claude Code: claude
  - Workspace directory: ~/workspace

================================================================================
EOF

# Create a helper script to display the SSH key
cat > /home/developer/show-ssh-key.sh << 'EOF'
#!/bin/bash
echo "Add this SSH public key to your GitHub account:"
echo "https://github.com/settings/ssh/new"
echo ""
cat ~/.ssh/id_ed25519.pub
echo ""
EOF

chmod +x /home/developer/show-ssh-key.sh
chown developer:developer /home/developer/show-ssh-key.sh

# Create marker file
touch "$MARKER_FILE"
chown developer:developer "$MARKER_FILE"

echo "First-boot setup complete!"
