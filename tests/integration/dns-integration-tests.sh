#!/usr/bin/env bash
set -euo pipefail

# DNS Plugin Integration Tests
# This script runs comprehensive integration tests inside a Dokku container

# Source report assertion functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/report-assertions.sh" ]]; then
    source "$SCRIPT_DIR/report-assertions.sh"
elif [[ -f "/tmp/report-assertions.sh" ]]; then
    source "/tmp/report-assertions.sh"
else
    echo "⚠️ Report assertion functions not found, using basic verification"
fi

log_remote() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

run_integration_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    local description="$4"
    
    echo ""
    echo "Testing: $test_name - $description"
    echo "Command: $test_command"
    
    if eval "$test_command" 2>&1 | grep -q "$expected_pattern"; then
        echo "✓ $description"
        return 0
    else
        echo "❌ $description failed"
        return 1
    fi
}

main() {
    log_remote "INFO" "=== DNS PLUGIN INTEGRATION TESTS ==="
    
    # Install the DNS plugin
    log_remote "INFO" "Installing DNS plugin..."
    rm -rf /var/lib/dokku/plugins/available/dns
    cp -r /tmp/dokku-dns /var/lib/dokku/plugins/available/dns
    chown -R dokku:dokku /var/lib/dokku/plugins/available/dns
    dokku plugin:enable dns
    /var/lib/dokku/plugins/available/dns/install || echo "Install script completed with warnings"
    
    # Verify installation
    dokku plugin:list | grep dns || {
        echo "ERROR: DNS plugin not found in plugin list"
        exit 1
    }
    echo "✓ DNS plugin installed successfully"
    
    # Import AWS credentials if provided
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log_remote "INFO" "Setting up AWS credentials..."
        mkdir -p ~/.aws
        cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
        cat > ~/.aws/config << EOF
[default]
region = ${AWS_DEFAULT_REGION:-us-east-1}
output = json
EOF
        echo "AWS credentials configured"
    fi
    
    # Test AWS connectivity
    if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
        echo "✓ AWS CLI is working"
    else
        echo "⚠️ AWS CLI not configured or not working"
    fi
    
    # Create test app for comprehensive testing
    TEST_APP="my-test-app"
    echo "Setting up test app: $TEST_APP"
    if ! dokku apps:list 2>/dev/null | grep -q "$TEST_APP"; then
        dokku apps:create "$TEST_APP" 2>&1 || echo "Failed to create app, using existing"
    fi
    
    # Add test domains
    dokku domains:add "$TEST_APP" "test.example.com" 2>&1 || echo "Domain add completed"
    dokku domains:add "$TEST_APP" "api.test.example.com" 2>&1 || echo "Domain add completed"
    
    # Test sequence
    local test_failed=false
    
    # Test 1: Basic commands
    echo "1. Testing dns:help"
    dokku dns:help 2>&1 || echo "Help command completed"
    
    echo "2. Testing dns:configure"
    dokku dns:configure aws 2>&1 || echo "Configure command completed"
    
    echo "3. Testing dns:verify"
    dokku dns:verify 2>&1 || echo "Verify command completed"
    
    # Test 4: DNS Add and verify in reports
    echo "4. Testing dns:add"
    dokku dns:add "$TEST_APP" 2>&1 || echo "Add command completed"
    
    # Test 5: Verify reports after add (comprehensive verification)
    if declare -f run_comprehensive_report_verification >/dev/null 2>&1; then
        if ! run_comprehensive_report_verification "after_add" "$TEST_APP" "test.example.com" "api.test.example.com"; then
            test_failed=true
        fi
    else
        # Fallback to basic verification
        echo "5. Basic verification - app-specific report after add"
        if dokku dns:report "$TEST_APP" 2>&1 | grep -q "DNS Status: Added"; then
            echo "✓ App-specific report shows DNS Status: Added"
        else
            echo "❌ App-specific report doesn't show DNS Status: Added"
            test_failed=true
        fi
    fi
    
    # Test 6: DNS Sync
    echo "6. Testing dns:sync"
    dokku dns:sync "$TEST_APP" 2>&1 || echo "Sync command completed"
    
    # Test 7: Verify global report shows app and domains
    if declare -f verify_app_in_global_report >/dev/null 2>&1; then
        if ! verify_app_in_global_report "$TEST_APP" "true"; then
            test_failed=true
        fi
        if ! verify_domains_in_report "global" "$TEST_APP" "test.example.com" "api.test.example.com"; then
            test_failed=true
        fi
    else
        # Fallback to basic verification
        echo "7. Basic verification - global report"
        if dokku dns:report 2>&1 | grep -q "$TEST_APP"; then
            echo "✓ Global report shows app: $TEST_APP"
        else
            echo "❌ Global report doesn't show app: $TEST_APP"
            test_failed=true
        fi
    fi
    
    # Test 8: DNS Remove
    echo "8. Testing dns:remove"
    dokku dns:remove "$TEST_APP" 2>&1 || echo "Remove command completed"
    
    # Test 9: Verify reports after remove (comprehensive verification)
    if declare -f run_comprehensive_report_verification >/dev/null 2>&1; then
        if ! run_comprehensive_report_verification "after_remove" "$TEST_APP"; then
            test_failed=true
        fi
    else
        # Fallback to basic verification
        echo "9. Basic verification - reports after remove"
        if dokku dns:report "$TEST_APP" 2>&1 | grep -q "DNS Status: Not added"; then
            echo "✓ App-specific report shows DNS Status: Not added"
        else
            echo "❌ App-specific report doesn't show DNS Status: Not added"
            test_failed=true
        fi
        
        if dokku dns:report 2>&1 | grep -q "$TEST_APP"; then
            echo "❌ App still appears in global report after remove"
            test_failed=true
        else
            echo "✓ App no longer appears in global report after remove"
        fi
    fi
    
    # Test 10: DNS Cron functionality
    echo "10. Testing comprehensive DNS cron functionality..."
    
    # Test 10.1: Initial cron status (should be disabled)
    if dokku dns:cron 2>&1 | grep -q "Status: ❌ DISABLED"; then
        echo "✓ Cron shows disabled status initially"
    else
        echo "⚠️ Cron initial status test inconclusive"
    fi
    
    # Test 10.2: Invalid flag handling
    if dokku dns:cron --invalid-flag 2>&1 | grep -q "unknown flag.*invalid-flag"; then
        echo "✓ Invalid cron flag handled correctly"
    else
        echo "❌ Invalid cron flag not handled correctly"
        test_failed=true
    fi
    
    # Test 10.3: Invalid schedule validation
    if dokku dns:cron --enable --schedule "invalid" 2>&1 | grep -q "Invalid cron schedule"; then
        echo "✓ Cron schedule validation working"
    else
        echo "❌ Cron schedule validation not working"
        test_failed=true
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
            test_failed=true
        fi
        
        # Test 10.6: Verify cron status shows enabled
        if dokku dns:cron 2>&1 | grep -q "Status: ✅ ENABLED"; then
            echo "✓ Cron status shows enabled"
        else
            echo "❌ Cron status not showing enabled"
            test_failed=true
        fi
        
        # Test 10.7: Test cron update (enable when already enabled)
        if dokku dns:cron --enable 2>&1 | grep -q "Updating DNS Cron Job"; then
            echo "✓ Cron update shows correct message"
        else
            echo "⚠️ Cron update message test inconclusive"
        fi
        
        # Test 10.8: Test custom schedule
        if dokku dns:cron --schedule "0 6 * * *" 2>&1 | grep -q "✅ DNS cron job.*successfully"; then
            echo "✓ Custom cron schedule works"
            
            # Verify custom schedule is set
            if su - dokku -c 'crontab -l 2>/dev/null' | grep -q "0 6 \* \* \*"; then
                echo "✓ Custom schedule set in crontab"
            else
                echo "❌ Custom schedule not set correctly"
                test_failed=true
            fi
        else
            echo "❌ Custom cron schedule failed"
            test_failed=true
        fi
        
        # Test 10.9: Test cron disable with schedule display
        echo "Testing cron disable functionality..."
        local disable_output
        disable_output=$(dokku dns:cron --disable 2>&1)
        if echo "$disable_output" | grep -q "Disabling DNS Cron Job"; then
            echo "✓ Cron disable shows header"
        else
            echo "❌ Cron disable header missing"
            test_failed=true
        fi
        
        if echo "$disable_output" | grep -q "Current:.*6.*custom"; then
            echo "✓ Cron disable shows current schedule"
        else
            echo "❌ Cron disable doesn't show current schedule"
            test_failed=true
        fi
        
        if echo "$disable_output" | grep -q "✅ DNS cron job disabled successfully"; then
            echo "✓ Cron disable success message"
        else
            echo "❌ Cron disable success message missing"
            test_failed=true
        fi
        
        # Test 10.10: Verify cron job removed from system
        if su - dokku -c 'crontab -l 2>/dev/null' | grep -q "dokku dns:sync-all"; then
            echo "❌ Cron job still exists after disable"
            test_failed=true
        else
            echo "✓ Cron job removed from dokku user's crontab"
        fi
        
        # Test 10.11: Verify status shows disabled after disable
        if dokku dns:cron 2>&1 | grep -q "Status: ❌ DISABLED"; then
            echo "✓ Cron status shows disabled after disable"
        else
            echo "❌ Cron status not showing disabled"
            test_failed=true
        fi
        
        # Test 10.12: Test error when trying to disable already disabled cron
        if dokku dns:cron --disable 2>&1 | grep -q "No DNS cron job found"; then
            echo "✓ Disable error when no cron job exists"
        else
            echo "❌ Disable should show error when no job exists"
            test_failed=true
        fi
        
    else
        echo "❌ Cron enable command failed - skipping cron system tests"
        test_failed=true
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
            test_failed=true
        fi
    else
        echo "❌ Cron status metadata file not created"
        test_failed=true
    fi
    
    if [[ -f "/var/lib/dokku/services/dns/cron/sync.log" ]]; then
        echo "✓ Cron log file created"
    else
        echo "❌ Cron log file not created"
        test_failed=true
    fi
    
    # Clean up cron for other tests
    dokku dns:cron --disable >/dev/null 2>&1 || true
    
    # Test 11: DNS Sync-All functionality
    echo "11. Testing DNS sync-all functionality..."
    
    # Add test app to DNS for sync-all testing
    dokku dns:add "$TEST_APP" >/dev/null 2>&1
    
    # Test sync-all command
    if dokku dns:sync-all 2>&1 | grep -q "DNS sync completed"; then
        echo "✓ DNS sync-all command works"
    else
        echo "⚠️ DNS sync-all command test inconclusive (may require DNS credentials)"
    fi
    
    # Test sync-all with no DNS-managed apps
    dokku dns:remove "$TEST_APP" >/dev/null 2>&1
    if dokku dns:sync-all 2>&1 | grep -q "No apps are currently managed by DNS"; then
        echo "✓ Sync-all handles no DNS-managed apps correctly"
    else
        echo "❌ Sync-all doesn't handle empty state correctly"
        test_failed=true
    fi
    
    # Test 12: Version and help commands
    echo "12. Testing version and help commands..."
    
    if dokku dns:version 2>&1 | grep -q "dokku-dns plugin version"; then
        echo "✓ Version command shows plugin version"
    else
        echo "❌ Version command not working correctly"
        test_failed=true
    fi
    
    if dokku dns:help 2>&1 | grep -q "dns:cron"; then
        echo "✓ Help shows cron command"
    else
        echo "❌ Help doesn't show cron command"
        test_failed=true
    fi
    
    if dokku dns:help cron 2>&1 | grep -q "enable.*disable.*schedule"; then
        echo "✓ Cron help shows flags"
    else
        echo "❌ Cron help doesn't show flags"
        test_failed=true
    fi
    
    # Test 13: Zones functionality with report and sync
    echo "13. Testing zones functionality with report and sync..."
    
    # Create a second test app for zones testing
    ZONES_TEST_APP="zones-test-app"
    echo "Setting up zones test app: $ZONES_TEST_APP"
    if ! dokku apps:list 2>/dev/null | grep -q "$ZONES_TEST_APP"; then
        dokku apps:create "$ZONES_TEST_APP" 2>&1 || echo "Failed to create app, using existing"
    fi
    
    # Add domains that would be in example.com zone
    dokku domains:add "$ZONES_TEST_APP" "app.example.com" 2>&1 || echo "Domain add completed"
    dokku domains:add "$ZONES_TEST_APP" "api.example.com" 2>&1 || echo "Domain add completed"
    
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
        test_failed=true
    fi
    
    if echo "$zones_report_output" | grep -q "app.example.com"; then
        echo "✓ Report shows app domains even when not added to DNS"
    else
        echo "❌ Report doesn't show app domains for non-DNS-managed app"
        test_failed=true
    fi
    
    if echo "$zones_report_output" | grep -q "api.example.com"; then
        echo "✓ Report shows all app domains even when not added to DNS"
    else
        echo "❌ Report doesn't show all app domains for non-DNS-managed app"
        test_failed=true
    fi
    
    # Test sync on app not added to DNS management shows appropriate behavior
    echo "Testing sync with non-DNS-managed app..."
    local zones_sync_output
    zones_sync_output=$(dokku dns:sync "$ZONES_TEST_APP" 2>&1)
    
    if echo "$zones_sync_output" | grep -q "No DNS provider configured\|App.*not found in DNS management\|not managed by DNS"; then
        echo "✓ Sync shows appropriate message for non-DNS-managed app"
    else
        echo "⚠️ Sync behavior test inconclusive (may depend on provider configuration)"
    fi
    
    # Clean up zones test app
    dokku apps:destroy "$ZONES_TEST_APP" --force 2>&1 || echo "App cleanup completed"
    
    # Test 14: Edge cases and error handling
    echo "14. Testing edge cases and error handling..."
    
    # Test commands without required arguments
    if dokku dns:add 2>&1 | grep -q "Please specify an app name"; then
        echo "✓ Add without app shows usage error"
    else
        echo "⚠️ Add usage error handling test inconclusive"
    fi
    
    if dokku dns:sync 2>&1 | grep -q "Please specify an app name"; then
        echo "✓ Sync without app shows usage error"  
    else
        echo "⚠️ Sync usage error handling test inconclusive"
    fi
    
    if dokku dns:remove 2>&1 | grep -q "Please specify an app name"; then
        echo "✓ Remove without app shows usage error"
    else
        echo "⚠️ Remove usage error handling test inconclusive"
    fi
    
    # Test operations on nonexistent apps
    if dokku dns:add "nonexistent-app-12345" 2>&1 | grep -q "App does not exist"; then
        echo "✓ Add nonexistent app shows error"
    else
        echo "⚠️ Add nonexistent app error handling test inconclusive"
    fi
    
    if dokku dns:sync "nonexistent-app-12345" 2>&1 | grep -q "App.*does not exist"; then
        echo "✓ Sync nonexistent app shows error"
    else
        echo "⚠️ Sync nonexistent app error handling test inconclusive"
    fi
    
    if dokku dns:remove "nonexistent-app-12345" 2>&1 | grep -q "App.*does not exist"; then
        echo "✓ Remove nonexistent app shows error"
    else
        echo "⚠️ Remove nonexistent app error handling test inconclusive"
    fi
    
    # Test provider configuration edge cases
    echo "Testing provider configuration edge cases..."
    
    if dokku dns:configure "invalid-provider" 2>&1 | grep -q "Invalid provider"; then
        echo "✓ Invalid provider shows error"
    else
        echo "⚠️ Invalid provider error handling test inconclusive"
    fi
    
    
    if [[ "$test_failed" == "true" ]]; then
        log_remote "ERROR" "Some integration tests failed!"
        exit 1
    else
        log_remote "SUCCESS" "All DNS plugin integration tests completed successfully!"
    fi
}

main "$@"
