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
