#!/bin/bash
# Provider Discovery and Loading System
# This handles automatic discovery and loading of DNS providers

# Global provider state
LOADED_PROVIDERS=()
CURRENT_PROVIDER=""

# Load the base configuration
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get list of available providers
get_available_providers() {
    if [[ -f "$BASE_DIR/available" ]]; then
        grep -v '^#' "$BASE_DIR/available" | grep -v '^[[:space:]]*$'
    else
        echo "aws"  # Fallback to AWS only
    fi
}

# Check if a provider exists and is valid
validate_provider() {
    local provider_name="$1"
    local provider_dir="$BASE_DIR/$provider_name"
    
    # Check if provider directory exists
    if [[ ! -d "$provider_dir" ]]; then
        echo "Provider directory not found: $provider_dir" >&2
        return 1
    fi
    
    # Check if required files exist
    local required_files=("config.sh" "provider.sh")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$provider_dir/$file" ]]; then
            echo "Required provider file missing: $provider_dir/$file" >&2
            return 1
        fi
    done
    
    # Check if provider.sh defines required functions
    local required_functions=(
        "provider_validate_credentials"
        "provider_list_zones"
        "provider_get_zone_id"
        "provider_get_record"
        "provider_create_record"
        "provider_delete_record"
    )
    
    # Source the provider to check functions
    if ! source "$provider_dir/provider.sh" 2>/dev/null; then
        echo "Failed to source provider script: $provider_dir/provider.sh" >&2
        return 1
    fi
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" >/dev/null 2>&1; then
            echo "Required function missing in provider $provider_name: $func" >&2
            return 1
        fi
    done
    
    return 0
}

# Load a specific provider
load_provider() {
    local provider_name="$1"
    
    # Skip if already loaded
    if [[ " ${LOADED_PROVIDERS[*]} " =~ \ ${provider_name}\  ]]; then
        return 0
    fi
    
    # Validate provider first
    if ! validate_provider "$provider_name"; then
        return 1
    fi
    
    local provider_dir="$BASE_DIR/$provider_name"
    
    # Load provider configuration
    source "$provider_dir/config.sh"
    
    # Load provider implementation
    source "$provider_dir/provider.sh"
    
    # Call provider setup if available
    if declare -f "provider_setup_env" >/dev/null 2>&1; then
        provider_setup_env
    fi
    
    # Add to loaded providers list
    LOADED_PROVIDERS+=("$provider_name")
    
    echo "Loaded provider: $provider_name" >&2
    return 0
}

# Auto-detect and load the best available provider
auto_load_provider() {
    local providers=()
    # Use compatible array loading for older bash versions
    while IFS= read -r provider; do
        [[ -n "$provider" ]] && providers+=("$provider")
    done < <(get_available_providers)
    
    for provider in "${providers[@]}"; do
        if load_provider "$provider"; then
            # Test if provider credentials work
            if provider_validate_credentials 2>/dev/null; then
                CURRENT_PROVIDER="$provider"
                echo "Auto-selected provider: $provider" >&2
                return 0
            else
                echo "Provider $provider loaded but credentials invalid" >&2
            fi
        else
            echo "Failed to load provider: $provider" >&2
        fi
    done
    
    echo "No working provider found" >&2
    return 1
}

# Load specific provider by name
load_specific_provider() {
    local provider_name="$1"
    
    if [[ -z "$provider_name" ]]; then
        echo "Provider name is required" >&2
        return 1
    fi
    
    if load_provider "$provider_name"; then
        CURRENT_PROVIDER="$provider_name"
        return 0
    else
        return 1
    fi
}

# Get current provider name
get_current_provider() {
    echo "$CURRENT_PROVIDER"
}

# List all available providers
list_available_providers() {
    get_available_providers
}

# List all loaded providers
list_loaded_providers() {
    printf '%s\n' "${LOADED_PROVIDERS[@]}"
}

# Check if a provider is currently loaded
is_provider_loaded() {
    local provider_name="$1"
    [[ " ${LOADED_PROVIDERS[*]} " =~ \ ${provider_name}\  ]]
}

# Validate current provider is working
validate_current_provider() {
    if [[ -z "$CURRENT_PROVIDER" ]]; then
        echo "No provider currently loaded" >&2
        return 1
    fi
    
    if ! provider_validate_credentials; then
        echo "Current provider ($CURRENT_PROVIDER) credentials are invalid" >&2
        return 1
    fi
    
    return 0
}