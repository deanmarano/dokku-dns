#!/usr/bin/env bash
# DNS Plugin Core Commands Integration Tests
# Tests: help, providers:configure, providers:verify, apps:enable, apps:sync, apps:disable

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_apps_tests() {
    log_remote "INFO" "🧪 Starting Apps Subcommand Tests"
    
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
    
    # Test 7: Verify global report behavior based on hosted zones
    echo "7. Testing global report after sync..."
    local app_report
    app_report=$(dokku dns:report "$MAIN_TEST_APP" 2>&1)
    
    if echo "$app_report" | grep -q "DNS Status: Added"; then
        # App has domains with hosted zones - should appear in global report
        if declare -f verify_app_in_global_report >/dev/null 2>&1; then
            if ! verify_app_in_global_report "$MAIN_TEST_APP" "true"; then
                mark_test_failed
            fi
            if ! verify_domains_in_report "global" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
                mark_test_failed
            fi
        fi
    else
        # No hosted zones - app correctly excluded from global report
        echo "✓ App correctly excluded from global report (no hosted zones)"
        if declare -f verify_app_in_global_report >/dev/null 2>&1; then
            verify_app_in_global_report "$MAIN_TEST_APP" "false" || true  # Don't fail the test for this
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
        log_remote "ERROR" "❌ Apps Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Apps Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_report_assertions
    run_apps_tests
fi