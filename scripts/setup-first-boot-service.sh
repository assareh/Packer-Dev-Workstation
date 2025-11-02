#!/bin/bash
# Sets up a systemd service to run first-boot setup on initial VM boot

set -e

echo "===> Setting up first-boot service..."

# Copy the first-boot script to system location
cp /tmp/first-boot-setup.sh /usr/local/bin/first-boot-setup.sh
chmod +x /usr/local/bin/first-boot-setup.sh

# Create systemd service
cat > /etc/systemd/system/first-boot-setup.service << 'EOF'
[Unit]
Description=First Boot Setup - Generate SSH keys and configure Git
After=network-online.target
Wants=network-online.target
ConditionPathExists=!/home/developer/.first-boot-complete

[Service]
Type=oneshot
ExecStart=/usr/local/bin/first-boot-setup.sh
RemainAfterExit=yes
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
systemctl enable first-boot-setup.service

echo "===> First-boot service configured!"
