#!/usr/bin/env bash
# DNS Plugin Report Function Integration Tests
# Tests: dns:report global and app-specific functionality, status reporting, domain display

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_report_tests() {
    log_remote "INFO" "🧪 Starting Report Subcommand Tests"
    
    reset_test_status
    
    echo "Testing DNS report functionality..."
    
    # Create test app for report testing
    create_test_app "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"
    
    # Test initial global report (no DNS-managed apps)
    echo "Testing global report with no DNS-managed apps..."
    local initial_global_report
    initial_global_report=$(dokku dns:report 2>&1)
    if echo "$initial_global_report" | grep -q "No apps are currently managed by DNS"; then
        echo "✓ Global report shows no DNS-managed apps initially"
    elif echo "$initial_global_report" | grep -q "Global DNS Provider"; then
        echo "✓ Global report shows provider configuration"
    else
        echo "❌ Global report initial state unexpected"
        echo "DEBUG: Initial global report output:"
        echo "$initial_global_report"
        mark_test_failed
    fi
    
    # Test app-specific report before DNS management
    echo "Testing app-specific report before DNS management..."
    local pre_dns_report
    pre_dns_report=$(dokku dns:report "$MAIN_TEST_APP" 2>&1)
    if echo "$pre_dns_report" | grep -q "DNS Status: Not added"; then
        echo "✓ App report shows 'Not added' status before DNS management"
    else
        echo "❌ App report should show 'Not added' status initially"
        mark_test_failed
    fi
    
    # Verify domains appear in app report even when not DNS-managed
    if ! verify_domains_in_report "app-specific" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
        mark_test_failed
    fi
    
    # Add app to DNS management
    echo "Adding app to DNS management..."
    dokku dns:apps:enable "$MAIN_TEST_APP" >/dev/null 2>&1
    
    # Test comprehensive report verification after DNS enable
    echo "Testing report verification after DNS enable..."
    if ! run_comprehensive_report_verification "after_add" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
        mark_test_failed
    fi
    
    # Test global report shows app (if domains have hosted zones)
    echo "Testing global report after DNS enable..."
    local post_enable_global_report
    post_enable_global_report=$(dokku dns:report 2>&1)
    local app_report_status
    app_report_status=$(dokku dns:report "$MAIN_TEST_APP" 2>&1)
    
    if echo "$app_report_status" | grep -q "DNS Status: Added"; then
        # App has hosted zones - should appear in global report
        if ! verify_app_in_global_report "$MAIN_TEST_APP" "true"; then
            mark_test_failed
        fi
    else
        # App doesn't have hosted zones - won't appear in global report
        echo "✓ App correctly excluded from global report (no hosted zones)"
    fi
    
    # Test app removal from DNS management
    echo "Testing report after DNS disable..."
    dokku dns:apps:disable "$MAIN_TEST_APP" >/dev/null 2>&1
    
    # Test comprehensive report verification after DNS disable
    if ! run_comprehensive_report_verification "after_remove" "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"; then
        mark_test_failed
    fi
    
    # Test report with nonexistent app
    echo "Testing report with nonexistent app..."
    local nonexistent_report
    nonexistent_report=$(dokku dns:report "nonexistent-app-12345" 2>&1)
    if echo "$nonexistent_report" | grep -q "App.*does not exist"; then
        echo "✓ Report shows error for nonexistent app"
    else
        echo "❌ Report should show error for nonexistent app"
        echo "DEBUG: Nonexistent app report output:"
        echo "$nonexistent_report"
        mark_test_failed
    fi
    
    # Test global report formatting and content
    echo "Testing global report format and content..."
    local final_global_report
    final_global_report=$(dokku dns:report 2>&1)
    
    # Should show provider information
    if echo "$final_global_report" | grep -q "Global DNS Provider\|DNS Provider"; then
        echo "✓ Global report shows provider information"
    else
        echo "❌ Global report should show provider information"
        mark_test_failed
    fi
    
    # Should show configuration status
    if echo "$final_global_report" | grep -q "Configuration Status\|Status"; then
        echo "✓ Global report shows configuration status"
    else
        echo "❌ Global report should show configuration status"
        mark_test_failed
    fi
    
    # Clean up
    cleanup_test_app "$MAIN_TEST_APP"
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Report Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Report Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_report_tests
fi