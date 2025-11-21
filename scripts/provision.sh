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

# Install Node.js and npm
echo "===> Installing Node.js and npm..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install GitHub CLI
echo "===> Installing GitHub CLI..."
sudo mkdir -p -m 755 /etc/apt/keyrings
wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
sudo apt-get install -y gh

# Install Claude Code CLI
echo "===> Installing Claude Code CLI..."
curl -fsSL https://claude.ai/install.sh | bash

# Install OpenAI Codex CLI
echo "===> Installing OpenAI Codex CLI..."
sudo npm install -g @openai/codex

# Install Gemini CLI
echo "===> Installing Gemini CLI..."
sudo npm install -g google/gemini-cli

# Verify installations
echo "===> Verifying installations..."
git --version
python --version
pip --version
node --version
npm --version
gh --version

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
# Add SSH public key to authorized_keys if provided
if [ -n "$SSH_PUBLIC_KEY" ]; then
    echo "===> Adding SSH public key to authorized_keys..."
    mkdir -p /home/developer/.ssh
    chmod 700 /home/developer/.ssh
    echo "$SSH_PUBLIC_KEY" > /home/developer/.ssh/authorized_keys
    chmod 600 /home/developer/.ssh/authorized_keys
    chown -R developer:developer /home/developer/.ssh
fi

# Keep password authentication enabled during build - will be disabled in cleanup
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config
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
