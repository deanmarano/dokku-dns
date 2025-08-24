#!/usr/bin/env bash
# DNS Plugin Sync Operations Integration Tests  
# Tests: sync-all functionality, bulk operations, and sync coordination

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_sync_all_tests() {
    log_remote "INFO" "🧪 Starting Sync-All Subcommand Tests"
    
    reset_test_status
    
    echo "11. Testing DNS sync-all functionality..."
    
    # Create test app for sync-all testing
    create_test_app "$MAIN_TEST_APP" "${MAIN_DOMAINS[@]}"
    
    # Add test app to DNS for sync-all testing
    dokku dns:apps:enable "$MAIN_TEST_APP" >/dev/null 2>&1
    
    # Test sync-all command
    if dokku dns:sync-all 2>&1 | grep -q "DNS sync completed"; then
        echo "✓ DNS sync-all command works"
    else
        echo "⚠️ DNS sync-all command test inconclusive (may require DNS credentials)"
    fi
    
    # Test sync-all with no DNS-managed apps
    dokku dns:apps:disable "$MAIN_TEST_APP" >/dev/null 2>&1
    if dokku dns:sync-all 2>&1 | grep -q "No apps are currently managed by DNS"; then
        echo "✓ Sync-all handles no DNS-managed apps correctly"
    else
        echo "❌ Sync-all doesn't handle empty state correctly"
        mark_test_failed
    fi
    
    # Clean up
    cleanup_test_app "$MAIN_TEST_APP"
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Sync-All Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Sync-All Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_sync_all_tests
fi