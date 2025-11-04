#!/bin/bash
set -e

# Prevent debconf warnings about non-interactive frontend
export DEBIAN_FRONTEND=noninteractive

echo "===> Starting cleanup..."

# Remove unnecessary packages
echo "===> Removing unnecessary packages..."
sudo apt-get autoremove -y
sudo apt-get autoclean -y

# Clear package cache
echo "===> Clearing package cache..."
sudo apt-get clean

# Remove temporary files
echo "===> Removing temporary files..."
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*

# Clear logs
echo "===> Clearing logs..."
sudo find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;
sudo find /var/log -type f -name "*.gz" -delete
sudo find /var/log -type f -name "*.1" -delete

# Clear command history
echo "===> Clearing command history..."
history -c
cat /dev/null > ~/.bash_history
sudo truncate -s 0 /root/.bash_history

# Harden SSH - disable password authentication
echo "===> Hardening SSH configuration..."
# Remove all existing conflicting settings
sudo sed -i '/^#*PermitRootLogin/d' /etc/ssh/sshd_config
sudo sed -i '/^#*PasswordAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*ChallengeResponseAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*KbdInteractiveAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*PubkeyAuthentication/d' /etc/ssh/sshd_config
sudo sed -i '/^#*AuthenticationMethods/d' /etc/ssh/sshd_config

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
echo "===> Disabling PAM password authentication..."
sudo sed -i 's/@include common-auth/#@include common-auth/' /etc/pam.d/sshd

# Disable ssh.socket to prevent socket activation config issues
sudo systemctl stop ssh.socket 2>/dev/null || true
sudo systemctl disable ssh.socket 2>/dev/null || true

# Validate SSH config
echo "===> Validating SSH configuration..."
sudo sshd -t

# Note: Not restarting SSH here - will be regenerated on first boot with new host keys

# Clear SSH keys (will be regenerated on first boot)
echo "===> Clearing SSH host keys..."
sudo rm -f /etc/ssh/ssh_host_*

# Clear cloud-init logs and cache
echo "===> Clearing cloud-init cache..."
sudo cloud-init clean --logs --seed

# Clear machine-id
echo "===> Clearing machine-id..."
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id

# Zero out free space to aid compression
echo "===> Zeroing out free space (this may take a while)..."
sudo dd if=/dev/zero of=/EMPTY bs=1M || true
sudo rm -f /EMPTY

# Sync to ensure all writes are complete
sync

echo "===> Cleanup complete!"
