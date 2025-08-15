#!/bin/bash
# Initialize cron for DNS plugin testing

echo "Installing and starting cron for DNS plugin testing..."

# Install cron
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y cron

# Start cron service
service cron start

# Enable cron to start on boot
update-rc.d cron enable

# Verify cron is running
if service cron status | grep -q "running"; then
    echo "✅ Cron installed and running successfully"
else
    echo "❌ Failed to start cron service"
    exit 1
fi

echo "Cron initialization completed"