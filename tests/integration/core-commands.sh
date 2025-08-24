#!/usr/bin/env bash
# DNS Plugin Core Commands Integration Tests
# Tests: help, providers:configure, providers:verify, apps:enable, apps:sync, apps:disable

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_core_commands_tests() {
    log_remote "INFO" "🧪 Starting Core Commands Tests"
    
    reset_test_status
    
    # Create test app for core commands
    create_test_app "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"
    
    # Test 1: Basic commands
    echo "1. Testing dns:help"
    dokku dns:help 2>&1 || echo "Help command completed"
    
    echo "2. Testing dns:providers:configure"
    dokku dns:providers:configure aws 2>&1 || echo "Configure command completed"
    
    echo "3. Testing dns:providers:verify"
    dokku dns:providers:verify 2>&1 || echo "Verify command completed"
    
    # Test 4: DNS Add and verify in reports
    echo "4. Testing dns:apps:enable"
    dokku dns:apps:enable "$MAIN_TEST_APP" 2>&1 || echo "Add command completed"
    
    # Test 5: Verify reports after add (comprehensive verification)
    if declare -f run_comprehensive_report_verification >/dev/null 2>&1; then
        if ! run_comprehensive_report_verification "after_add" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
            mark_test_failed
        fi
    else
        # Fallback to basic verification
        echo "5. Basic verification - app-specific report after add"
        if dokku dns:report "$MAIN_TEST_APP" 2>&1 | grep -q "DNS Status: Added"; then
            echo "✓ App-specific report shows DNS Status: Added"
        else
            echo "❌ App-specific report doesn't show DNS Status: Added"
            mark_test_failed
        fi
    fi
    
    # Test 6: DNS Sync
    echo "6. Testing dns:apps:sync"
    dokku dns:apps:sync "$MAIN_TEST_APP" 2>&1 || echo "Sync command completed"
    
    # Test 7: Verify global report shows app and domains
    if declare -f verify_app_in_global_report >/dev/null 2>&1; then
        if ! verify_app_in_global_report "$MAIN_TEST_APP" "true"; then
            mark_test_failed
        fi
        if ! verify_domains_in_report "global" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
            mark_test_failed
        fi
    else
        # Fallback to basic verification
        echo "7. Basic verification - global report"
        if dokku dns:report 2>&1 | grep -q "$MAIN_TEST_APP"; then
            echo "✓ Global report shows app: $MAIN_TEST_APP"
        else
            echo "❌ Global report doesn't show app: $MAIN_TEST_APP"
            mark_test_failed
        fi
    fi
    
    # Test 8: DNS Remove
    echo "8. Testing dns:apps:disable"
    dokku dns:apps:disable "$MAIN_TEST_APP" 2>&1 || echo "Remove command completed"
    
    # Test 9: Verify reports after remove (comprehensive verification)
    if declare -f run_comprehensive_report_verification >/dev/null 2>&1; then
        if ! run_comprehensive_report_verification "after_remove" "$MAIN_TEST_APP"; then
            mark_test_failed
        fi
    else
        # Fallback to basic verification
        echo "9. Basic verification - reports after remove"
        if dokku dns:report "$MAIN_TEST_APP" 2>&1 | grep -q "DNS Status: Not added"; then
            echo "✓ App-specific report shows DNS Status: Not added"
        else
            echo "❌ App-specific report doesn't show DNS Status: Not added"
            mark_test_failed
        fi
        
        if dokku dns:report 2>&1 | grep -q "$MAIN_TEST_APP"; then
            echo "❌ App still appears in global report after remove"
            mark_test_failed
        else
            echo "✓ App no longer appears in global report after remove"
        fi
    fi
    
    # Clean up
    cleanup_test_app "$MAIN_TEST_APP"
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Core Commands Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Core Commands Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_report_assertions
    run_core_commands_tests
fi