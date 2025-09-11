#!/bin/bash
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# AWS Provider Add Functions  
# AWS hosted zone validation for domain addition

dns_provider_aws_validate_domain_for_addition() {
    local DOMAIN="$1"
    
    # Validate AWS CLI and credentials
    if ! dns_provider_aws_validate_cli; then
        echo "AWS CLI not available or not configured"
        return 1
    fi
    
    # Check if a hosted zone exists for this domain
    local zone_id
    zone_id=$(dns_provider_aws_get_hosted_zone_id "$DOMAIN")
    if [[ -z "$zone_id" ]]; then
        echo "No hosted zone found for domain: $DOMAIN"
        return 1
    fi
    
    echo "Found hosted zone $zone_id for domain: $DOMAIN"
    return 0
}