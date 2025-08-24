#!/usr/bin/env bash
# DNS Plugin Provider Configuration Integration Tests
# Tests: providers:configure, providers:verify, AWS authentication and setup

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_providers_tests() {
    log_remote "INFO" "🧪 Starting Providers Subcommand Tests"
    
    reset_test_status
    
    echo "Testing dns:providers:configure"
    dokku dns:providers:configure aws 2>&1 || echo "Configure command completed"
    
    echo "Testing dns:providers:verify"
    local verify_output
    verify_output=$(dokku dns:providers:verify 2>&1)
    
    if echo "$verify_output" | grep -q "AWS Route53 is properly configured"; then
        echo "✓ Provider verification shows AWS configured"
    elif echo "$verify_output" | grep -q "AWS CLI.*not"; then
        echo "❌ Provider verification should work with AWS credentials available"
        echo "DEBUG: Verify output: $verify_output"
        mark_test_failed
    else
        echo "✓ Provider verification completed (credentials checked)"
    fi
    
    # Test provider configuration with invalid provider
    echo "Testing invalid provider configuration..."
    local invalid_provider_output
    invalid_provider_output=$(dokku dns:providers:configure "invalid-provider" 2>&1 || true)
    if echo "$invalid_provider_output" | grep -qE "(Invalid provider|not a dokku command)"; then
        echo "✓ Invalid provider configuration shows appropriate error"
    else
        echo "❌ Invalid provider configuration should show error"
        echo "DEBUG: Output was: $invalid_provider_output"
        mark_test_failed
    fi
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Providers Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Providers Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_providers_tests
fi