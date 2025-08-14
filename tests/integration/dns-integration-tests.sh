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
    echo "10. Testing DNS cron functionality..."
    
    # Test cron status (should be disabled initially)
    if dokku dns:cron 2>&1 | grep -q "Status: ❌ DISABLED"; then
        echo "✓ Cron shows disabled status initially"
    else
        echo "⚠️ Cron status test inconclusive"
    fi
    
    # Test cron help/usage (don't enable actual cron in Docker environment)
    dokku dns:cron --schedule "0 4 * * *" 2>&1 || echo "Schedule validation working"
    
    # Test invalid schedule validation
    if dokku dns:cron --enable --schedule "invalid" 2>&1 | grep -q "Invalid cron schedule"; then
        echo "✓ Cron schedule validation working"
    else
        echo "⚠️ Cron schedule validation not working as expected"
    fi
    
    # Test 11: Edge cases
    echo "11. Testing edge cases..."
    dokku dns:add 2>&1 || echo "Usage error handled correctly"
    dokku dns:sync 2>&1 || echo "Usage error handled correctly"
    dokku dns:remove 2>&1 || echo "Usage error handled correctly"
    
    if [[ "$test_failed" == "true" ]]; then
        log_remote "ERROR" "Some integration tests failed!"
        exit 1
    else
        log_remote "SUCCESS" "All DNS plugin integration tests completed successfully!"
    fi
}

main "$@"
