#!/bin/bash
# Initialize cron for DNS plugin testing

echo "Installing cron and AWS CLI for DNS plugin testing..."

# Install cron and AWS CLI
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y cron awscli

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

# Verify AWS CLI is available
if command -v aws >/dev/null 2>&1; then
    echo "✅ AWS CLI installed successfully"
    aws --version
else
    echo "❌ Failed to install AWS CLI"
    exit 1
fi

echo "Cron and AWS CLI initialization completed"