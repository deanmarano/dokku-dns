#!/bin/bash
source "$(dirname "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)")/config"
source "$(dirname "$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)")/functions"

# AWS Provider Common Functions
# Shared utilities for AWS Route53 DNS operations

dns_provider_aws_validate_credentials() {
    return 0
}

dns_provider_aws_setup_env() {
    return 0
}

dns_provider_aws_validate_cli() {
    # Validate AWS CLI and credentials
    if ! command -v aws >/dev/null 2>&1; then
        return 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

dns_provider_aws_get_hosted_zone_id() {
    local DOMAIN="$1"
    
    # Validate AWS CLI and credentials
    if ! dns_provider_aws_validate_cli; then
        return 1
    fi
    
    # Try to find hosted zone for domain or its parent domains
    local current_domain="$DOMAIN"
    
    while [[ "$current_domain" == *.* ]]; do
        # Check if there's a hosted zone for the current domain
        local zone_id
        zone_id=$(aws route53 list-hosted-zones --query "HostedZones[?Name=='${current_domain}.'].Id" --output text 2>/dev/null)
        
        if [[ -n "$zone_id" && "$zone_id" != "None" ]]; then
            # Found a hosted zone, return the zone ID without the /hostedzone/ prefix
            echo "${zone_id#/hostedzone/}"
            return 0
        fi
        
        # Remove the leftmost subdomain and try again
        current_domain="${current_domain#*.}"
    done
    
    # No hosted zone found
    return 1
}

dns_provider_aws_get_record_ip() {
    local DOMAIN="$1"
    
    # Validate AWS CLI and credentials
    if ! dns_provider_aws_validate_cli; then
        return 1
    fi
    
    # Get hosted zone ID for this domain
    local zone_id
    zone_id=$(dns_provider_aws_get_hosted_zone_id "$DOMAIN")
    if [[ -z "$zone_id" ]]; then
        return 1
    fi
    
    # Query Route53 for A record
    local record_ip
    record_ip=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$zone_id" \
        --query "ResourceRecordSets[?Name=='${DOMAIN}.' && Type=='A'].ResourceRecords[0].Value" \
        --output text 2>/dev/null)
    
    if [[ -n "$record_ip" && "$record_ip" != "None" ]]; then
        echo "$record_ip"
        return 0
    fi
    
    return 1
}