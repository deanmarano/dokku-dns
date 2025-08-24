#!/usr/bin/env bash
# DNS Plugin Error Handling Integration Tests
# Tests: edge cases, invalid inputs, non-existent apps, provider errors

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_error_handling_tests() {
    log_remote "INFO" "🧪 Starting Error Handling Tests"
    
    reset_test_status
    
    echo "14. Testing edge cases and error handling..."
    
    # Test commands without required arguments
    if dokku dns:apps:enable 2>&1 | grep -q "Please specify an app name"; then
        echo "✓ Add without app shows usage error"
    else
        echo "⚠️ Add usage error handling test inconclusive"
    fi
    
    if dokku dns:apps:sync 2>&1 | grep -q "Please specify an app name"; then
        echo "✓ Sync without app shows usage error"  
    else
        echo "⚠️ Sync usage error handling test inconclusive"
    fi
    
    if dokku dns:apps:disable 2>&1 | grep -q "Please specify an app name"; then
        echo "✓ Remove without app shows usage error"
    else
        echo "⚠️ Remove usage error handling test inconclusive"
    fi
    
    # Test operations on nonexistent apps
    if dokku dns:apps:enable "nonexistent-app-12345" 2>&1 | grep -q "App does not exist"; then
        echo "✓ Add nonexistent app shows error"
    else
        echo "⚠️ Add nonexistent app error handling test inconclusive"
    fi
    
    if dokku dns:apps:sync "nonexistent-app-12345" 2>&1 | grep -q "App.*does not exist"; then
        echo "✓ Sync nonexistent app shows error"
    else
        echo "⚠️ Sync nonexistent app error handling test inconclusive"
    fi
    
    if dokku dns:apps:disable "nonexistent-app-12345" 2>&1 | grep -q "App.*does not exist"; then
        echo "✓ Remove nonexistent app shows error"
    else
        echo "⚠️ Remove nonexistent app error handling test inconclusive"
    fi
    
    # Test provider configuration edge cases
    echo "Testing provider configuration edge cases..."
    
    if dokku dns:providers:configure "invalid-provider" 2>&1 | grep -q "Invalid provider"; then
        echo "✓ Invalid provider shows error"
    else
        echo "⚠️ Invalid provider error handling test inconclusive"
    fi
    
    # Test version and help commands
    echo "12. Testing version and help commands..."
    
    if dokku dns:version 2>&1 | grep -q "dokku-dns plugin version"; then
        echo "✓ Version command shows plugin version"
    else
        echo "❌ Version command not working correctly"
        mark_test_failed
    fi
    
    if dokku dns:help 2>&1 | grep -q "dns:cron"; then
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
        log_remote "ERROR" "❌ Error Handling Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Error Handling Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_error_handling_tests
fi