#!/usr/bin/env bash
set -euo pipefail

# DNS Plugin Integration Tests
# Tests core DNS functionality against real Dokku installation

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Test configuration
TEST_APP="dns-test-app"
TEST_DOMAINS=("test.example.com" "api.test.example.com")

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ️  $*${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $*${NC}"
}

log_error() {
    echo -e "${RED}❌ $*${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $*${NC}"
}

# Test assertion helpers
assert_success() {
    local description="$1"
    shift
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if "$@" >/dev/null 2>&1; then
        log_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_output_contains() {
    local description="$1"
    local expected="$2"
    shift 2
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local output
    if output=$("$@" 2>&1) && echo "$output" | grep -q "$expected"; then
        log_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$description"
        log_error "Expected output to contain: $expected"
        log_error "Actual output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_output_contains_ignore_exit() {
    local description="$1"
    local expected="$2"
    shift 2
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    local output
    output=$("$@" 2>&1) || true  # Ignore exit code
    if echo "$output" | grep -q "$expected"; then
        log_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "$description"
        log_error "Expected output to contain: $expected"
        log_error "Actual output: $output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_failure() {
    local description="$1"
    shift
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if "$@" >/dev/null 2>&1; then
        log_error "$description (expected failure but command succeeded)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    else
        log_success "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

# Setup and cleanup functions
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test app if it doesn't exist
    if ! dokku apps:list | grep -q "^$TEST_APP$"; then
        dokku apps:create "$TEST_APP" >/dev/null 2>&1
        log_success "Created test app: $TEST_APP"
    else
        log_info "Test app already exists: $TEST_APP"
    fi
    
    # Add test domains
    for domain in "${TEST_DOMAINS[@]}"; do
        dokku domains:add "$TEST_APP" "$domain" >/dev/null 2>&1 || true
    done
    log_success "Added test domains to $TEST_APP"
}

cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    
    # Clean up any cron jobs that might have been created during testing
    if crontab -l 2>/dev/null | grep -q "dokku dns:sync-all"; then
        crontab -l 2>/dev/null | grep -v "dokku dns:sync-all" | crontab - 2>/dev/null || true
        log_info "Cleaned up DNS cron jobs"
    fi
    
    # Remove from DNS management if added
    dokku dns:remove "$TEST_APP" >/dev/null 2>&1 || true
    
    # Remove test app
    if dokku apps:list | grep -q "^$TEST_APP$"; then
        dokku apps:destroy "$TEST_APP" --force >/dev/null 2>&1 || true
        log_success "Cleaned up test app: $TEST_APP"
    fi
}

# Test suites
test_dns_help() {
    log_info "Testing DNS help commands..."
    
    assert_output_contains "Main help shows usage" "usage:" dokku dns:help
    assert_output_contains "Main help shows available commands" "dns:add" dokku dns:help
    assert_output_contains "Configure help works" "configure or change the global DNS provider" dokku dns:help configure
    assert_output_contains "Add help works" "add app domains to DNS provider" dokku dns:help add
    assert_output_contains "Version shows plugin version" "dokku-dns plugin version" dokku dns:version
}

test_dns_configuration() {
    log_info "Testing DNS configuration..."
    
    # Test invalid provider
    assert_failure "Invalid provider should fail" dokku dns:configure invalid-provider
    
    # Test AWS configuration
    assert_success "AWS provider configuration should succeed" dokku dns:configure aws
    assert_output_contains "Provider configured as AWS" "aws" dokku dns:report
    
    # Test provider switching
    assert_success "Can switch to cloudflare provider" dokku dns:configure cloudflare
    assert_output_contains "Provider switched to cloudflare" "cloudflare" dokku dns:report
    
    # Switch back to AWS for other tests
    dokku dns:configure aws >/dev/null 2>&1
}

test_dns_verify() {
    log_info "Testing DNS verification..."
    
    # Configure AWS first
    dokku dns:configure aws >/dev/null 2>&1
    
    # Test verification (will show AWS CLI not configured, which is expected)
    assert_output_contains_ignore_exit "Verify shows AWS CLI status" "AWS CLI is not installed. Please install it first:" dokku dns:verify
    
    # Test with no provider (remove provider configuration)
    rm -f /var/lib/dokku/services/dns/PROVIDER 2>/dev/null || true
    assert_output_contains_ignore_exit "Verify with no provider shows error" "No provider configured" dokku dns:verify
    
    # Restore AWS provider
    dokku dns:configure aws >/dev/null 2>&1
}

test_dns_app_management() {
    log_info "Testing DNS app management..."
    
    # Ensure AWS provider is configured
    dokku dns:configure aws >/dev/null 2>&1
    
    # Test adding app to DNS
    assert_output_contains "Can add app to DNS" "added to DNS" dokku dns:add "$TEST_APP"
    
    # Test app appears in global report
    assert_output_contains "App appears in global report" "$TEST_APP" dokku dns:report
    
    # Test app-specific report
    assert_output_contains "App-specific report works" "Domain Analysis:" dokku dns:report "$TEST_APP"
    
    # Test sync (will show AWS CLI not configured, which is expected)
    assert_output_contains_ignore_exit "Sync shows expected message" "AWS CLI is not installed" dokku dns:sync "$TEST_APP"
    
    # Test removing app from DNS
    assert_output_contains "Can remove app from DNS" "removed from DNS" dokku dns:remove "$TEST_APP"
}

test_dns_cron() {
    log_info "Testing DNS cron functionality..."
    
    # Ensure AWS provider is configured (required for cron operations)
    dokku dns:configure aws >/dev/null 2>&1
    
    # First, determine the current state and adapt tests accordingly
    local cron_status_output
    cron_status_output=$(dokku dns:cron 2>&1)
    
    if echo "$cron_status_output" | grep -q "Status: ✅ ENABLED"; then
        # Cron is currently enabled, start by testing disable functionality
        log_info "Cron is currently enabled, testing disable first..."
        
        assert_output_contains "Cron shows enabled status" "Status: ✅ ENABLED" dokku dns:cron
        assert_output_contains "Cron shows active job details" "Active Job:" dokku dns:cron
        
        # Test disabling cron
        assert_output_contains "Can disable cron automation" "✅ DNS cron job disabled successfully!" dokku dns:cron --disable
        
        # Verify disabled state
        assert_output_contains "Cron shows disabled status after disable" "Status: ❌ DISABLED" dokku dns:cron
        assert_failure "Cron job removed from system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        
        # Now test enabling 
        assert_output_contains "Can enable cron automation" "✅ DNS cron job enabled successfully!" dokku dns:cron --enable
        assert_success "Cron job exists in system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        
    else
        # Cron is currently disabled, start by testing enable functionality
        log_info "Cron is currently disabled, testing enable first..."
        
        assert_output_contains "Cron shows disabled status initially" "Status: ❌ DISABLED" dokku dns:cron
        assert_output_contains "Cron shows enable command when disabled" "Enable cron: dokku dns:cron --enable" dokku dns:cron
        
        # Test enabling cron
        assert_output_contains "Can enable cron automation" "✅ DNS cron job enabled successfully!" dokku dns:cron --enable
        assert_success "Cron job exists in system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        
        # Test enabled state
        assert_output_contains "Cron shows enabled status" "Status: ✅ ENABLED" dokku dns:cron
        assert_output_contains "Cron shows active job details" "Active Job:" dokku dns:cron
        
        # Now test disabling
        assert_output_contains "Can disable cron automation" "✅ DNS cron job disabled successfully!" dokku dns:cron --disable
        assert_failure "Cron job removed from system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
    fi
    
    # Test enabling when already exists (should show warning)
    dokku dns:cron --enable >/dev/null 2>&1  # Ensure it's enabled
    assert_output_contains "Enable shows warning when already exists" "DNS cron job already exists" dokku dns:cron --enable
    
    # Test that disabling again shows error
    dokku dns:cron --disable >/dev/null 2>&1  # Disable it first
    assert_failure "Disable shows error when not exists" dokku dns:cron --disable
    
    # Test cron flag validation
    assert_failure "Invalid cron flag should fail" dokku dns:cron --invalid-flag
    assert_output_contains_ignore_exit "Invalid flag shows helpful error" "Unknown option" dokku dns:cron --invalid-flag
    
    # Test metadata and file creation
    dokku dns:cron --enable >/dev/null 2>&1
    assert_success "Cron metadata files created" test -f /var/lib/dokku/services/dns/cron/status
    assert_success "Cron log file created" test -f /var/lib/dokku/services/dns/cron/sync.log
    assert_output_contains "Cron status file contains enabled" "enabled" cat /var/lib/dokku/services/dns/cron/status
    
    # Clean up - disable cron for other tests
    dokku dns:cron --disable >/dev/null 2>&1 || true
}

test_error_conditions() {
    log_info "Testing error conditions..."
    
    # Test commands with nonexistent apps
    assert_failure "Add nonexistent app should fail" dokku dns:add nonexistent-app
    assert_failure "Sync nonexistent app should fail" dokku dns:sync nonexistent-app
    assert_failure "Remove nonexistent app should fail" dokku dns:remove nonexistent-app
    
    # Test missing arguments
    assert_failure "Add without app should fail" dokku dns:add
    assert_failure "Sync without app should fail" dokku dns:sync
    assert_failure "Remove without app should fail" dokku dns:remove
}

# Main test execution
main() {
    echo -e "${BLUE}🧪 DNS Plugin Integration Tests${NC}"
    echo "=================================="
    
    # Check if we're in a Dokku environment
    if ! command -v dokku >/dev/null 2>&1; then
        log_error "Dokku not found. Please run these tests in a Dokku environment."
        exit 1
    fi
    
    # Check if DNS plugin is available
    if ! dokku help | grep -q dns; then
        log_error "DNS plugin not installed. Please install the plugin first."
        exit 1
    fi
    
    # Setup
    setup_test_environment
    
    # Run test suites
    test_dns_help
    test_dns_configuration  
    test_dns_verify
    test_dns_app_management
    test_dns_cron
    test_error_conditions
    
    # Cleanup
    cleanup_test_environment
    
    # Results
    echo
    echo "=================================="
    echo -e "${BLUE}📊 Test Results${NC}"
    echo "=================================="
    echo -e "Total tests: ${TESTS_TOTAL}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}💥 Some tests failed.${NC}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi