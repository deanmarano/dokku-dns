#!/bin/bash
# AWS Provider Main File
# Loads all AWS provider components

# Get the directory where this script is located
PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common AWS utilities first
source "$PROVIDER_DIR/aws/common.sh"

# Load AWS-specific modules
source "$PROVIDER_DIR/aws/add.sh"
source "$PROVIDER_DIR/aws/sync.sh" 
source "$PROVIDER_DIR/aws/report.sh"

# Provider function interface - standardized entry points
# These functions provide consistent interfaces across all providers

# Validate provider is properly configured
dns_provider_validate() {
    dns_provider_aws_validate_credentials
}

# Setup provider environment
dns_provider_setup_env() {
    dns_provider_aws_setup_env  
}

# Get hosted zone ID for a domain
dns_provider_get_zone_id() {
    dns_provider_aws_get_hosted_zone_id "$@"
}

# Get current DNS record IP for a domain
dns_provider_get_record_ip() {
    dns_provider_aws_get_record_ip "$@"
}

# Sync DNS records for an app
dns_provider_sync_app() {
    dns_provider_aws_sync_app "$@"
}

# Validate domain can be added to DNS management  
dns_provider_validate_domain() {
    dns_provider_aws_validate_domain_for_addition "$@"
}

# Get domain status for reporting
dns_provider_get_domain_status() {
    dns_provider_aws_get_domain_status "$@"
}