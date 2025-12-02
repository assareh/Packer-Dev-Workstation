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
    unzip \
    build-essential \
    software-properties-common \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    tmux \
    zsh

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

# Install AWS CLI v2
echo "===> Installing AWS CLI..."
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
unzip -q /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
rm -rf /tmp/awscliv2.zip /tmp/aws

# Install Azure CLI
echo "===> Installing Azure CLI..."
curl -fsSL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Google Cloud SDK
echo "===> Installing Google Cloud SDK..."
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null
sudo apt-get update
sudo apt-get install -y google-cloud-cli

# Verify installations
echo "===> Verifying installations..."
git --version
python --version
pip --version
node --version
npm --version
gh --version
aws --version
az version --output table
gcloud version

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

# Configure zsh with autosuggestions and syntax highlighting
echo "===> Configuring zsh with plugins..."
sudo apt-get install -y zsh-autosuggestions zsh-syntax-highlighting

# Set zsh as default shell for developer user
sudo chsh -s $(which zsh) developer

# Create .zshrc with full configuration
cat > /home/developer/.zshrc << 'ZSHRC_EOF'
# Enable plugins
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS

# Enable command completion with menu selection
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# Custom prompt similar to Pure/Starship style
PROMPT='# %F{magenta}%n%f at %F{yellow}%m%f in %F{blue}%~%f [%F{green}%*%f]
→ '

# Key bindings for history search
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# Useful aliases
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
ZSHRC_EOF

sudo chown developer:developer /home/developer/.zshrc

# Set timezone to UTC
echo "===> Setting timezone to UTC..."
sudo timedatectl set-timezone UTC

echo "===> Provisioning complete!"
