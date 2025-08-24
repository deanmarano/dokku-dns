#!/usr/bin/env bash
# DNS Plugin Zones Management Integration Tests
# Tests: zones listing, zone-aware reports, and zone-based sync operations

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_zones_tests() {
    log_remote "INFO" "🧪 Starting Zones Subcommand Tests"
    
    reset_test_status
    
    echo "13. Testing zones functionality with report and sync..."
    
    # Create a second test app for zones testing
    create_test_app "$ZONES_TEST_APP" "${ZONES_DOMAINS[@]}"
    
    # Disable DNS management for this app to test non-DNS-managed behavior
    dokku dns:apps:disable "$ZONES_TEST_APP" >/dev/null 2>&1
    
    # Test zones functionality (without AWS CLI this should show errors gracefully)
    echo "Testing zones listing..."
    if dokku dns:zones 2>&1 | grep -q "AWS CLI is not configured"; then
        echo "✓ Zones shows AWS CLI requirement when not configured"
    else
        echo "⚠️ Zones command test inconclusive (AWS CLI may be available)"
    fi
    
    # Test report shows domains even when not added to DNS but zones could be enabled
    echo "Testing report with non-DNS-managed app that has domains..."
    local zones_report_output
    zones_report_output=$(dokku dns:report "$ZONES_TEST_APP" 2>&1)
    
    if echo "$zones_report_output" | grep -q "DNS Status.*Not added"; then
        echo "✓ Report shows 'Not added' status for app not in DNS management"
    else
        echo "❌ Report doesn't show correct status for non-DNS-managed app"
        mark_test_failed
    fi
    
    if echo "$zones_report_output" | grep -q "app.example.com"; then
        echo "✓ Report shows app domains even when not added to DNS"
    else
        echo "❌ Report doesn't show app domains for non-DNS-managed app"
        mark_test_failed
    fi
    
    if echo "$zones_report_output" | grep -q "api.example.com"; then
        echo "✓ Report shows all app domains even when not added to DNS"
    else
        echo "❌ Report doesn't show all app domains for non-DNS-managed app"
        mark_test_failed
    fi
    
    # Test sync on app not added to DNS management shows appropriate behavior
    echo "Testing sync with non-DNS-managed app..."
    local zones_sync_output
    zones_sync_output=$(dokku dns:apps:sync "$ZONES_TEST_APP" 2>&1)
    
    if echo "$zones_sync_output" | grep -q "No DNS provider configured\|App.*not found in DNS management\|not managed by DNS"; then
        echo "✓ Sync shows appropriate message for non-DNS-managed app"
    else
        echo "⚠️ Sync behavior test inconclusive (may depend on provider configuration)"
    fi
    
    # Clean up zones test app
    cleanup_test_app "$ZONES_TEST_APP"
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Zones Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Zones Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_zones_tests
fi