#!/bin/bash
set -e

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
curl -fsSL https://claude.ai/install.sh | sh

# Verify installations
echo "===> Verifying installations..."
git --version
python --version
pip --version

# Configure Git with sensible defaults
echo "===> Configuring Git..."
git config --system init.defaultBranch main
git config --system pull.rebase false
git config --system credential.helper store

# Install common Python development tools
echo "===> Installing Python development tools..."
pip install --upgrade pip
pip install \
    virtualenv \
    pylint \
    black \
    pytest \
    ipython

# Configure SSH for better security
echo "===> Configuring SSH..."
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Enable and start SSH
sudo systemctl enable ssh
sudo systemctl restart ssh

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
