#!/usr/bin/env bash
# DNS Plugin Cron Functionality Integration Tests
# Tests: cron status, enable, disable, schedules, metadata, and system integration

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

run_cron_tests() {
    log_remote "INFO" "🧪 Starting Cron Subcommand Tests"
    
    reset_test_status
    
    echo "10. Testing comprehensive DNS cron functionality..."
    
    # Ensure clean state - disable any existing cron job
    dokku dns:cron --disable >/dev/null 2>&1 || true
    sleep 1
    
    # Test 10.1: Initial cron status (should be disabled)
    local initial_status_output
    initial_status_output=$(dokku dns:cron 2>&1)
    if echo "$initial_status_output" | grep -q "Status: ❌ DISABLED"; then
        echo "✓ Cron shows disabled status initially"
    else
        echo "❌ Cron should show disabled status initially"
        echo "DEBUG: Initial status output was:"
        echo "$initial_status_output"
        mark_test_failed
    fi
    
    # Test 10.2: Invalid flag handling
    local invalid_flag_output
    invalid_flag_output=$(dokku dns:cron --invalid-flag 2>&1 || true)
    if echo "$invalid_flag_output" | grep -q "unknown flag: --invalid-flag"; then
        echo "✓ Invalid cron flag handled correctly"
    else
        echo "❌ Invalid cron flag not handled correctly"
        mark_test_failed
    fi
    
    # Test 10.3: Invalid schedule validation
    local invalid_schedule_output
    invalid_schedule_output=$(dokku dns:cron --enable --schedule "invalid" 2>&1 || true)
    if echo "$invalid_schedule_output" | grep -q "Invalid cron schedule.*Must have 5 fields"; then
        echo "✓ Cron schedule validation working"
    else
        echo "❌ Cron schedule validation not working"
        mark_test_failed
    fi
    
    # Test 10.4: Enable cron with default schedule
    echo "Testing cron enable functionality..."
    if dokku dns:cron --enable 2>&1 | grep -q "✅ DNS cron job.*successfully"; then
        echo "✓ Cron enable command works"
        
        # Test 10.5: Verify cron job exists in dokku user's crontab
        if su - dokku -c 'crontab -l 2>/dev/null' | grep -q "dokku dns:sync-all"; then
            echo "✓ Cron job exists in dokku user's crontab"
        else
            echo "❌ Cron job not found in dokku user's crontab"
            mark_test_failed
        fi
        
        # Test 10.6: Verify cron status shows enabled
        sleep 1  # Allow cron system to update
        local enabled_status_output
        enabled_status_output=$(dokku dns:cron 2>&1)
        if echo "$enabled_status_output" | grep -q "Status: ✅ ENABLED"; then
            echo "✓ Cron status shows enabled"
        else
            echo "❌ Cron status not showing enabled"
            mark_test_failed
        fi
        
        # Test 10.7: Test cron update (enable when already enabled)
        local cron_update_output
        cron_update_output=$(dokku dns:cron --enable 2>&1)
        if echo "$cron_update_output" | grep -q "Updating DNS Cron Job"; then
            echo "✓ Cron update shows correct message"
        else
            echo "❌ Cron update should show 'Updating DNS Cron Job' message"
            echo "DEBUG: Update output was:"
            echo "$cron_update_output"
            mark_test_failed
        fi
        
        # Test 10.8: Test custom schedule
        if dokku dns:cron --schedule "0 6 * * *" 2>&1 | grep -q "✅ DNS cron job.*successfully"; then
            echo "✓ Custom cron schedule works"
            
            # Verify custom schedule is set
            if su - dokku -c 'crontab -l 2>/dev/null' | grep -q "0 6 \* \* \*"; then
                echo "✓ Custom schedule set in crontab"
            else
                echo "❌ Custom schedule not set correctly"
                mark_test_failed
            fi
        else
            echo "❌ Custom cron schedule failed"
            mark_test_failed
        fi
        
        # Test 10.9: Test cron disable with schedule display
        echo "Testing cron disable functionality..."
        local disable_output
        disable_output=$(dokku dns:cron --disable 2>&1)
        
        if echo "$disable_output" | grep -q "Disabling DNS Cron Job"; then
            echo "✓ Cron disable shows header"
        else
            echo "❌ Cron disable header missing"
            mark_test_failed
        fi
        
        if echo "$disable_output" | grep -q "Current:.*0 6"; then
            echo "✓ Cron disable shows current schedule"
        else
            echo "❌ Cron disable doesn't show current schedule"
            mark_test_failed
        fi
        
        if echo "$disable_output" | grep -q "✅ DNS cron job disabled successfully"; then
            echo "✓ Cron disable success message"
        else
            echo "❌ Cron disable success message missing"
            mark_test_failed
        fi
        
        # Test 10.10: Verify cron job removed from system
        if su - dokku -c 'crontab -l 2>/dev/null' | grep -q "dokku dns:sync-all"; then
            echo "❌ Cron job still exists after disable"
            mark_test_failed
        else
            echo "✓ Cron job removed from dokku user's crontab"
        fi
        
        # Test 10.11: Verify status shows disabled after disable
        sleep 1  # Allow cron system to update
        local disabled_status_output
        disabled_status_output=$(dokku dns:cron 2>&1)
        if echo "$disabled_status_output" | grep -q "Status: ❌ DISABLED"; then
            echo "✓ Cron status shows disabled after disable"
        else
            echo "❌ Cron status not showing disabled"
            mark_test_failed
        fi
        
        # Test 10.12: Test error when trying to disable already disabled cron
        local double_disable_output
        double_disable_output=$(dokku dns:cron --disable 2>&1 || true)
        if echo "$double_disable_output" | grep -q "No DNS cron job found"; then
            echo "✓ Disable error when no cron job exists"
        else
            echo "❌ Disable should show error when no job exists"
            mark_test_failed
        fi
        
    else
        echo "❌ Cron enable command failed - skipping cron system tests"
        mark_test_failed
    fi
    
    # Test 10.13: Test cron metadata and logs
    echo "Testing cron metadata and logs..."
    dokku dns:cron --enable >/dev/null 2>&1  # Enable for metadata tests
    
    if [[ -f "/var/lib/dokku/services/dns/cron/status" ]]; then
        echo "✓ Cron status metadata file created"
        if grep -q "enabled" "/var/lib/dokku/services/dns/cron/status"; then
            echo "✓ Cron status file contains 'enabled'"
        else
            echo "❌ Cron status file doesn't contain 'enabled'"
            mark_test_failed
        fi
    else
        echo "❌ Cron status metadata file not created"
        mark_test_failed
    fi
    
    if [[ -f "/var/lib/dokku/services/dns/cron/sync.log" ]]; then
        echo "✓ Cron log file created"
    else
        echo "❌ Cron log file not created"
        mark_test_failed
    fi
    
    # Clean up cron for other tests
    dokku dns:cron --disable >/dev/null 2>&1 || true
    
    if is_test_failed; then
        log_remote "ERROR" "❌ Cron Subcommand Tests: FAILED"
        return 1
    else
        log_remote "SUCCESS" "✅ Cron Subcommand Tests: PASSED"
        return 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_cron_tests
fi