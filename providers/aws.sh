#!/bin/bash
# AWS Provider Main File
# Legacy compatibility layer - loads the new AWS provider system

# Load the new AWS provider implementation
PROVIDER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$PROVIDER_DIR/aws/provider.sh"

# Legacy compatibility functions - map old names to new interface
dns_provider_aws_validate_credentials() {
    provider_validate_credentials
}

dns_provider_aws_setup_env() {
    provider_setup_env
}

dns_provider_aws_get_hosted_zone_id() {
    provider_get_zone_id "$@"
}

dns_provider_aws_get_record_ip() {
    local domain="$1"
    local zone_id
    if zone_id=$(provider_get_zone_id "$domain"); then
        provider_get_record "$zone_id" "$domain" "A"
    else
        return 1
    fi
}

dns_provider_aws_sync_app() {
    local app_name="$1"
    
    # Load the adapter layer to use the new provider system
    local ADAPTER_PATH
    ADAPTER_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/adapter.sh"
    
    if [[ ! -f "$ADAPTER_PATH" ]]; then
        echo "DNS adapter not found - using basic compatibility mode" >&2
        return 1
    fi
    
    source "$ADAPTER_PATH"
    
    # Initialize the provider system (single provider mode - AWS only)
    if ! init_provider_system "aws"; then
        echo "Failed to initialize AWS provider" >&2
        return 1
    fi
    
    # Use the new dns_sync_app function
    dns_sync_app "$app_name"
}

# Provider function interface - standardized entry points
dns_provider_validate() {
    provider_validate_credentials
}

dns_provider_setup_env() {
    provider_setup_env
}

dns_provider_get_zone_id() {
    provider_get_zone_id "$@"
}

dns_provider_get_record_ip() {
    local domain="$1"
    local zone_id
    if zone_id=$(provider_get_zone_id "$domain"); then
        provider_get_record "$zone_id" "$domain" "A"
    else
        return 1
    fi
}

dns_provider_sync_app() {
    # Load and use the adapter layer
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    init_provider_system "aws"
    dns_sync_app "$@"
}

dns_provider_validate_domain() {
    provider_get_zone_id "$@" >/dev/null 2>&1
}

dns_provider_get_domain_status() {
    local domain="$1"
    local server_ip="$2"
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    init_provider_system "aws"
    dns_get_domain_status "$domain" "$server_ip"
}