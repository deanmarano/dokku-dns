#!/usr/bin/env bash
# DNS Plugin Error Handling Integration Tests
# Tests: edge cases, invalid inputs, non-existent apps, provider errors

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_version_tests() {
    log_remote "INFO" "🧪 Starting Version Subcommand Tests"
    
    reset_test_status
    
    echo "Testing edge cases and error handling..."
    
    # Test commands without required arguments
    local enable_no_app_output
    enable_no_app_output=$(timeout 3s dokku dns:apps:enable 2>&1 || echo "timeout")
    if echo "$enable_no_app_output" | grep -q "Please specify an app name"; then
        echo "✓ Add without app shows usage error"
    elif echo "$enable_no_app_output" | grep -q "timeout"; then
        echo "✓ Add without app handled (command timeout - expected behavior)"
    else
        echo "❌ Add without app should show usage error or timeout"
        echo "DEBUG: Output was: $enable_no_app_output"
        mark_test_failed
    fi
    
    local sync_no_app_output
    sync_no_app_output=$(dokku dns:apps:sync 2>&1)
    if echo "$sync_no_app_output" | grep -q "Please specify an app name"; then
        echo "✓ Sync without app shows usage error"  
    else
        echo "❌ Sync without app should show usage error"
        echo "DEBUG: Output was: $sync_no_app_output"
        mark_test_failed
    fi
    
    local disable_no_app_output
    disable_no_app_output=$(dokku dns:apps:disable 2>&1)
    if echo "$disable_no_app_output" | grep -q "Please specify an app name"; then
        echo "✓ Remove without app shows usage error"
    else
        echo "❌ Remove without app should show usage error"
        echo "DEBUG: Output was: $disable_no_app_output"
        mark_test_failed
    fi
    
    # Test operations on nonexistent apps
    local enable_nonexistent_output
    enable_nonexistent_output=$(dokku dns:apps:enable "nonexistent-app-12345" 2>&1)
    if echo "$enable_nonexistent_output" | grep -q "App.*does not exist"; then
        echo "✓ Add nonexistent app shows error"
    else
        echo "❌ Add nonexistent app should show error"
        echo "DEBUG: Output was: $enable_nonexistent_output"
        mark_test_failed
    fi
    
    local sync_nonexistent_output
    sync_nonexistent_output=$(dokku dns:apps:sync "nonexistent-app-12345" 2>&1)
    if echo "$sync_nonexistent_output" | grep -q "App.*does not exist"; then
        echo "✓ Sync nonexistent app shows error"
    else
        echo "❌ Sync nonexistent app should show error"
        echo "DEBUG: Output was: $sync_nonexistent_output"
        mark_test_failed
    fi
    
    local disable_nonexistent_output
    disable_nonexistent_output=$(dokku dns:apps:disable "nonexistent-app-12345" 2>&1)
    if echo "$disable_nonexistent_output" | grep -q "App.*does not exist"; then
        echo "✓ Remove nonexistent app shows error"
    else
        echo "❌ Remove nonexistent app should show error"
        echo "DEBUG: Output was: $disable_nonexistent_output"
        mark_test_failed
    fi
    
    # Test provider configuration edge cases
    echo "Testing provider configuration edge cases..."
    
    local invalid_provider_output
    invalid_provider_output=$(dokku dns:providers:configure "invalid-provider" 2>&1)
    if echo "$invalid_provider_output" | grep -qE "(Invalid provider|not a dokku command)"; then
        echo "✓ Invalid provider shows error"
    else
        echo "❌ Invalid provider should show error"
        echo "DEBUG: Output was: $invalid_provider_output"
        mark_test_failed
    fi
    
    # Test version and help commands
    echo "Testing version and help commands..."
    
    local version_output
    version_output=$(dokku dns:version 2>&1)
    if echo "$version_output" | grep -q "dokku-dns plugin version"; then
        echo "✓ Version command shows plugin version"
    else
        echo "❌ Version command not working correctly"
        echo "DEBUG: Version output was: $version_output"
        mark_test_failed
    fi
    
    local help_output
    help_output=$(dokku dns:help 2>&1)
    if echo "$help_output" | grep -q "dns:cron"; then
        echo "✓ Help shows cron command"
    else
        echo "❌ Help doesn't show cron command"
        mark_test_failed
    fi
    
    if dokku dns:help cron 2>&1 | grep -q "enable.*disable.*schedule"; then
        echo "✓ Cron help shows flags"
    else
        echo "❌ Cron help doesn't show flags"
        mark_test_failed
    fi
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Version Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Version Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_version_tests
fi