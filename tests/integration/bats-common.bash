#!/usr/bin/env bash

# Common helper functions for BATS integration tests
# shellcheck disable=SC2154  # status and output are BATS built-in variables

# Load plugin configuration
if [[ -f "/var/lib/dokku/plugins/available/dns/config" ]]; then
    source "/var/lib/dokku/plugins/available/dns/config"
elif [[ -f "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/../config" ]]; then
    source "$(dirname "$(dirname "${BASH_SOURCE[0]}")")/../config"
fi

# Helper function to check if DNS plugin is available
check_dns_plugin_available() {
    if [[ ! -f "/var/lib/dokku/plugins/available/dns/plugin.toml" ]]; then
        skip "DNS plugin not available in test environment"
    fi
}

# Helper function to skip tests if AWS credentials are not available
skip_if_no_aws_credentials() {
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        skip "AWS CLI not available or not configured"
    fi
}

# Setup mock provider for testing when AWS is not available
setup_mock_provider() {
    # Export mock API key to enable mock provider
    export MOCK_API_KEY="test-key"
    
    # Disable AWS credentials to force mock provider usage
    export AWS_ACCESS_KEY_ID="invalid"
    export AWS_SECRET_ACCESS_KEY="invalid" 
    unset AWS_SESSION_TOKEN 2>/dev/null || true
    unset AWS_PROFILE 2>/dev/null || true
    
    # Clear any existing provider cache to force re-detection
    unset CURRENT_PROVIDER 2>/dev/null || true
    
    # Enable example.com zone for integration tests
    if command -v dokku >/dev/null 2>&1; then
        dokku dns:zones:enable example.com >/dev/null 2>&1 || true
    fi
}

# Helper function to create test app with domains
setup_test_app() {
    local app_name="$1"
    local domain1="${2:-app.example.com}"
    local domain2="${3:-api.example.com}"
    
    # Setup mock provider for integration tests
    setup_mock_provider
    
    if ! dokku apps:list 2>/dev/null | grep -q "$app_name"; then
        dokku apps:create "$app_name" >/dev/null 2>&1
    fi
    
    # Add test domains  
    dokku domains:add "$app_name" "$domain1" >/dev/null 2>&1 || true
    if [[ -n "$domain2" ]]; then
        dokku domains:add "$app_name" "$domain2" >/dev/null 2>&1 || true
    fi
    
    # Ensure app is not in DNS management initially
    dokku dns:apps:disable "$app_name" >/dev/null 2>&1 || true
}

# Helper function to clean up test app
cleanup_test_app() {
    local app_name="$1"
    
    if [[ -n "$app_name" ]]; then
        dokku dns:apps:disable "$app_name" >/dev/null 2>&1 || true
        dokku apps:destroy "$app_name" --force >/dev/null 2>&1 || true
    fi
}

# BATS assertion helpers
assert_success() {
    if [[ $status -ne 0 ]]; then
        echo "Command failed with status $status"
        echo "Output: $output"
        return 1
    fi
}

assert_failure() {
    if [[ $status -eq 0 ]]; then
        echo "Expected command to fail but it succeeded"
        echo "Output: $output"
        return 1
    fi
}

assert_output() {
    local flag="$1"
    local expected="$2"
    
    case "$flag" in
        --partial)
            if [[ ! "$output" =~ $expected ]]; then
                echo "Expected output to contain: '$expected'"
                echo "Actual output: '$output'"
                return 1
            fi
            ;;
        *)
            if [[ "$output" != "$expected" ]]; then
                echo "Expected: '$expected'"
                echo "Actual: '$output'"
                return 1
            fi
            ;;
    esac
}

# Helper to check if output contains a specific pattern
assert_output_contains() {
    local pattern="$1"
    if [[ ! "$output" =~ $pattern ]]; then
        echo "Expected output to contain: '$pattern'"
        echo "Actual output: '$output'"
        return 1
    fi
}

# Helper to check if output contains any of multiple patterns
assert_output_contains_any() {
    local patterns=("$@")
    local found=false
    
    for pattern in "${patterns[@]}"; do
        if [[ "$output" =~ $pattern ]]; then
            found=true
            break
        fi
    done
    
    if [[ "$found" != true ]]; then
        echo "Expected output to contain one of: ${patterns[*]}"
        echo "Actual output: '$output'"
        return 1
    fi
}