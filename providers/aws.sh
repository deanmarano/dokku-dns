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

# =============================================================================
# GENERIC PROVIDER INTERFACE - ZONE-BASED DELEGATION
# Subcommands call these generic functions, provider system handles delegation
# =============================================================================

# Create or update an A record for a domain
# Usage: provider_create_domain_record "example.com" "192.168.1.100" "300"  
provider_create_domain_record() {
    local domain="$1"
    local ip="$2"
    local ttl="${3:-300}"
    
    if [[ -z "$domain" ]] || [[ -z "$ip" ]]; then
        echo "Domain and IP are required" >&2
        return 1
    fi
    
    # Load the provider system to auto-delegate by zone
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    
    # Initialize provider system (auto-detects single/multi-provider mode)
    if ! init_provider_system; then
        echo "Failed to initialize provider system" >&2
        return 1
    fi
    
    # Use the generic adapter that auto-routes by zone
    dns_create_record "$domain" "A" "$ip" "$ttl"
}

# Get the current IP for a domain's A record
# Usage: current_ip=$(provider_get_domain_record "example.com")
provider_get_domain_record() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        echo "Domain is required" >&2
        return 1
    fi
    
    # Load the provider system to auto-delegate by zone
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    
    # Initialize provider system
    if ! init_provider_system; then
        echo "Failed to initialize provider system" >&2
        return 1
    fi
    
    # Use the generic adapter that auto-routes by zone
    dns_get_record "$domain" "A"
}

# Delete an A record for a domain
# Usage: provider_delete_domain_record "example.com"
provider_delete_domain_record() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        echo "Domain is required" >&2
        return 1
    fi
    
    # Load the provider system to auto-delegate by zone
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    
    # Initialize provider system
    if ! init_provider_system; then
        echo "Failed to initialize provider system" >&2
        return 1
    fi
    
    # Use the generic adapter that auto-routes by zone
    dns_delete_record "$domain" "A"
}

# Create/update multiple A records with the same IP (batch operation)
# Usage: provider_batch_create_records "domain1.com domain2.com domain3.com" "192.168.1.100" "300"
provider_batch_create_records() {
    local domains="$1"
    local ip="$2"
    local ttl="${3:-300}"
    
    if [[ -z "$domains" ]] || [[ -z "$ip" ]]; then
        echo "Domains and IP are required" >&2
        return 1
    fi
    
    # Load the provider system to auto-delegate by zone
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    
    # Initialize provider system
    if ! init_provider_system; then
        echo "Failed to initialize provider system" >&2
        return 1
    fi
    
    local success_count=0
    local total_count=0
    
    # Process each domain - the adapter will route to correct provider automatically
    for domain in $domains; do
        total_count=$((total_count + 1))
        if dns_create_record "$domain" "A" "$ip" "$ttl"; then
            success_count=$((success_count + 1))
        else
            echo "Failed to create record for: $domain" >&2
        fi
    done
    
    echo "Batch operation complete: $success_count/$total_count records created"
    [[ $success_count -eq $total_count ]]
}

# Validate that a domain can be managed (has a provider with a zone for it)
# Usage: if provider_validate_domain "example.com"; then ... fi
provider_validate_domain() {
    local domain="$1"
    
    if [[ -z "$domain" ]]; then
        echo "Domain is required" >&2
        return 1
    fi
    
    # Load the provider system to auto-delegate by zone
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    
    # Initialize provider system
    if ! init_provider_system; then
        echo "Failed to initialize provider system" >&2
        return 1
    fi
    
    # Use the adapter to check if any provider can handle this domain
    dns_validate_domain "$domain"
}

# Get domain status (for reporting)
# Usage: status=$(provider_get_domain_status "example.com" "192.168.1.100")
provider_get_domain_status() {
    local domain="$1"
    local server_ip="$2"
    
    if [[ -z "$domain" ]] || [[ -z "$server_ip" ]]; then
        echo "Domain and server IP are required" >&2
        return 1
    fi
    
    # Load the provider system to auto-delegate by zone
    local PROVIDERS_DIR
    PROVIDERS_DIR="$(dirname "${BASH_SOURCE[0]}")"
    source "$PROVIDERS_DIR/adapter.sh"
    
    # Initialize provider system
    if ! init_provider_system; then
        echo "Failed to initialize provider system" >&2
        return 1
    fi
    
    # Use the adapter that auto-routes by zone
    dns_get_domain_status "$domain" "$server_ip"
}