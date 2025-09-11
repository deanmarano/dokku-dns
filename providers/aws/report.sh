#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# AWS Provider Report Functions
# AWS DNS record checking and IP resolution for reporting

dns_provider_aws_get_domain_status() {
    local DOMAIN="$1"
    local SERVER_IP="$2"
    
    # Get current DNS record IP from AWS
    local current_ip
    current_ip=$(dns_provider_aws_get_record_ip "$DOMAIN")
    
    if [[ -z "$current_ip" ]]; then
        echo "❌"  # No record
        return 1
    elif [[ "$current_ip" == "$SERVER_IP" ]]; then
        echo "✅"  # Correct IP
        return 0
    else
        echo "⚠️"   # Wrong IP
        return 1
    fi
}