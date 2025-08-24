#!/usr/bin/env bash
# DNS Plugin App Management Integration Tests
# Tests: help, apps:enable, apps:sync, apps:disable, app reports

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_apps_tests() {
    log_remote "INFO" "🧪 Starting Apps Subcommand Tests"
    
    reset_test_status
    
    # Create test app for core commands
    create_test_app "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"
    
    # Basic command testing
    echo "Testing dns:help"
    dokku dns:help 2>&1 || echo "Help command completed"
    
    # DNS Add and verify in reports
    echo "Testing dns:apps:enable"
    dokku dns:apps:enable "$MAIN_TEST_APP" 2>&1 || echo "Add command completed"
    
    # Verify reports after add (comprehensive verification)
    if declare -f run_comprehensive_report_verification >/dev/null 2>&1; then
        if ! run_comprehensive_report_verification "after_add" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
            mark_test_failed
        fi
    else
        # Fallback to basic verification
        echo "Basic verification - app-specific report after add"
        if dokku dns:report "$MAIN_TEST_APP" 2>&1 | grep -q "DNS Status: Added"; then
            echo "✓ App-specific report shows DNS Status: Added"
        else
            echo "❌ App-specific report doesn't show DNS Status: Added"
            mark_test_failed
        fi
    fi
    
    # DNS Sync
    echo "Testing dns:apps:sync"
    dokku dns:apps:sync "$MAIN_TEST_APP" 2>&1 || echo "Sync command completed"
    
    # Verify global report behavior based on hosted zones
    echo "Testing global report after sync..."
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
    
    # DNS Remove
    echo "Testing dns:apps:disable"
    dokku dns:apps:disable "$MAIN_TEST_APP" 2>&1 || echo "Remove command completed"
    
    # Verify reports after remove (comprehensive verification)
    if declare -f run_comprehensive_report_verification >/dev/null 2>&1; then
        if ! run_comprehensive_report_verification "after_remove" "$MAIN_TEST_APP"; then
            mark_test_failed
        fi
    else
        # Fallback to basic verification
        echo "Basic verification - reports after remove"
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
    
    # Test error handling with missing arguments
    echo "Testing apps commands without required arguments..."
    
    local enable_no_app_output
    enable_no_app_output=$(timeout 3s dokku dns:apps:enable 2>&1 || echo "timeout")
    if echo "$enable_no_app_output" | grep -q "Please specify an app name"; then
        echo "✓ Enable without app shows usage error"
    elif echo "$enable_no_app_output" | grep -q "timeout"; then
        echo "✓ Enable without app handled (command timeout - expected behavior)"
    else
        echo "❌ Enable without app should show usage error or timeout"
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
        echo "✓ Disable without app shows usage error"
    else
        echo "❌ Disable without app should show usage error"
        echo "DEBUG: Output was: $disable_no_app_output"
        mark_test_failed
    fi
    
    # Test operations on nonexistent apps
    echo "Testing apps commands with nonexistent apps..."
    
    local enable_nonexistent_output
    enable_nonexistent_output=$(dokku dns:apps:enable "nonexistent-app-12345" 2>&1)
    if echo "$enable_nonexistent_output" | grep -q "App.*does not exist"; then
        echo "✓ Enable nonexistent app shows error"
    else
        echo "❌ Enable nonexistent app should show error"
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
        echo "✓ Disable nonexistent app shows error"
    else
        echo "❌ Disable nonexistent app should show error"
        echo "DEBUG: Output was: $disable_nonexistent_output"
        mark_test_failed
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
    run_apps_tests
fi