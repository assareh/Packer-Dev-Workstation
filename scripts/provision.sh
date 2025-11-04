#!/bin/bash
set -e

# Prevent debconf warnings about non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

echo "===> Starting provisioning..."

# Update package lists
echo "===> Updating package lists..."
sudo apt-get update

# Install essential development tools
echo "===> Installing Git and development tools..."
sudo apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    tmux

# Install Python and pip
echo "===> Installing Python and pip..."
sudo apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python3-dev

# Set python3 as default python
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1
sudo update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Install Claude Code CLI
echo "===> Installing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

# Verify installations
echo "===> Verifying installations..."
git --version
python --version
pip --version

# Configure Git with sensible defaults
echo "===> Configuring Git..."
sudo git config --system init.defaultBranch main
sudo git config --system pull.rebase false
sudo git config --system credential.helper store

# Install common Python development tools
echo "===> Installing Python development tools..."
pip install --break-system-packages --upgrade pip
pip install --break-system-packages \
    virtualenv \
    pylint \
    black \
    pytest \
    ipython

# Configure SSH for better security
echo "===> Configuring SSH..."
# Add SSH public key to authorized_keys
echo "===> Adding SSH public key to authorized_keys..."
mkdir -p /home/developer/.ssh
chmod 700 /home/developer/.ssh
echo "$SSH_PUBLIC_KEY" > /home/developer/.ssh/authorized_keys
chmod 600 /home/developer/.ssh/authorized_keys
chown -R developer:developer /home/developer/.ssh

# Disable password authentication and root login
echo "===> Disabling password authentication..."
# Remove all existing conflicting settings
sudo sed -i '/^#*PermitRootLogin/d' /etc/ssh/sshd_config
sudo sed -i '/^#*PasswordAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*KbdInteractiveAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*PubkeyAuthentication/d' /etc/ssh/sshd_config

# Add explicit settings at the end of the config
cat << 'SSHEOF' | sudo tee -a /etc/ssh/sshd_config

# Custom security settings - disable password authentication
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
SSHEOF

# Disable PAM password authentication for SSH
echo "===> Configuring PAM to disable password auth for SSH..."
sudo sed -i 's/@include common-auth/#@include common-auth/' /etc/pam.d/sshd

# Validate SSH config
echo "===> Validating SSH configuration..."
sudo sshd -t

# Restart SSH service (not using systemctl restart to avoid socket activation issues)
echo "===> Restarting SSH service..."
sudo systemctl stop ssh.socket 2>/dev/null || true
sudo systemctl disable ssh.socket 2>/dev/null || true
sudo systemctl enable ssh
sudo systemctl restart ssh

# Verify SSH is running
sudo systemctl status ssh --no-pager

# Create workspace directory
echo "===> Creating workspace directory..."
mkdir -p /home/developer/workspace
chown developer:developer /home/developer/workspace

# Copy tmux configuration
echo "===> Configuring tmux..."
sudo cp /tmp/tmux.conf /home/developer/.tmux.conf
sudo chown developer:developer /home/developer/.tmux.conf

# Set timezone to UTC
echo "===> Setting timezone to UTC..."
sudo timedatectl set-timezone UTC

echo "===> Provisioning complete!"
