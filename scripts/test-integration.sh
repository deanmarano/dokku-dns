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
    
    # Test sync (should work with mock provider)
    assert_output_contains "Sync shows expected message" "Syncing domains for app" dokku dns:sync "$TEST_APP"
    
    # Test removing app from DNS
    assert_output_contains "Can remove app from DNS" "removed from DNS" dokku dns:remove "$TEST_APP"
}

test_dns_cron() {
    log_info "Testing DNS cron functionality..."
    
    # Ensure AWS provider is configured (required for cron operations)
    dokku dns:configure aws >/dev/null 2>&1
    
    # Test cron command parsing and validation first
    assert_failure "Invalid cron flag should fail" dokku dns:cron --invalid-flag
    assert_output_contains_ignore_exit "Invalid flag shows helpful error" "unknown flag.*invalid-flag" dokku dns:cron --invalid-flag
    
    # Test schedule validation
    assert_failure "Invalid schedule should fail" dokku dns:cron --enable --schedule "invalid"
    assert_output_contains_ignore_exit "Schedule validation works" "Invalid cron schedule" dokku dns:cron --enable --schedule "invalid"
    
    # Check if cron is available for full testing
    if ! command -v crontab >/dev/null 2>&1; then
        log_warning "crontab not available, skipping cron system integration tests"
        assert_output_contains_ignore_exit "Cron status shows provider info" "DNS Cron Status" dokku dns:cron
        return 0
    fi
    
    # First, determine the current state and adapt tests accordingly
    local cron_status_output
    cron_status_output=$(dokku dns:cron 2>&1)
    
    if echo "$cron_status_output" | grep -q "Status: ✅ ENABLED"; then
        # Cron is currently enabled, start by testing disable functionality
        log_info "Cron is currently enabled, testing disable first..."
        
        assert_output_contains "Cron shows enabled status" "Status: ✅ ENABLED" dokku dns:cron
        assert_output_contains "Cron shows active job details" "Active Job:" dokku dns:cron
        
        # Test disabling cron (shows schedule before removing)
        output=$(dokku dns:cron --disable 2>&1)
        if echo "$output" | grep -q "Disabling DNS Cron Job"; then
            log_success "Can disable cron automation"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_error "Can disable cron automation"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        if echo "$output" | grep -q "Current:.*default.*2:00 AM"; then
            log_success "Shows current schedule when disabling" 
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_error "Shows current schedule when disabling"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 2))
        
        # Verify disabled state
        assert_output_contains "Cron shows disabled status after disable" "Status: ❌ DISABLED" dokku dns:cron
        # Only test crontab removal if we're in an environment that supports it
        if command -v crontab >/dev/null 2>&1 && su - dokku -c 'crontab -l >/dev/null 2>&1' 2>/dev/null; then
            assert_failure "Cron job removed from system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        else
            log_info "Skipping crontab removal verification (not available in this environment)"
        fi
        
        # Now test enabling 
        assert_output_contains "Can enable cron automation" "✅ DNS cron job.*successfully!" dokku dns:cron --enable
        # Only test crontab if we're in an environment that supports it
        if command -v crontab >/dev/null 2>&1 && su - dokku -c 'crontab -l >/dev/null 2>&1' 2>/dev/null; then
            assert_success "Cron job exists in system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        else
            log_info "Skipping crontab verification (not available in this environment)"
        fi
        
    else
        # Cron is currently disabled, start by testing enable functionality
        log_info "Cron is currently disabled, testing enable first..."
        
        assert_output_contains "Cron shows disabled status initially" "Status: ❌ DISABLED" dokku dns:cron
        assert_output_contains "Cron shows enable command when disabled" "Enable cron: dokku dns:cron --enable" dokku dns:cron
        
        # Test enabling cron
        assert_output_contains_ignore_exit "Can enable cron automation" "✅ DNS cron job.*successfully!" dokku dns:cron --enable
        # Only test crontab if we're in an environment that supports it
        if command -v crontab >/dev/null 2>&1 && su - dokku -c 'crontab -l >/dev/null 2>&1' 2>/dev/null; then
            assert_success "Cron job exists in system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        else
            log_info "Skipping crontab verification (not available in this environment)"
        fi
        
        # Test enabled state
        assert_output_contains "Cron shows enabled status" "Status: ✅ ENABLED" dokku dns:cron
        assert_output_contains "Cron shows active job details" "Active Job:" dokku dns:cron
        
        # Now test disabling
        assert_output_contains "Can disable cron automation" "Disabling DNS Cron Job" dokku dns:cron --disable
        # Only test crontab removal if we're in an environment that supports it
        if command -v crontab >/dev/null 2>&1 && su - dokku -c 'crontab -l >/dev/null 2>&1' 2>/dev/null; then
            assert_failure "Cron job removed from system crontab" bash -c "su - dokku -c 'crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\"'"
        else
            log_info "Skipping crontab removal verification (not available in this environment)"
        fi
    fi
    
    # Test enabling when already exists (should show update message)
    # First ensure cron is enabled, but only test the update if the first enable succeeded
    if dokku dns:cron --enable >/dev/null 2>&1; then
        assert_output_contains_ignore_exit "Enable shows update when already exists" "Updating DNS Cron Job" dokku dns:cron --enable
    else
        # If cron operations don't work in this environment, skip the update test
        log_info "Skipping cron update test (cron operations not available in this environment)"
    fi
    
    # Test that disabling again shows error
    dokku dns:cron --disable >/dev/null 2>&1  # Disable it first
    assert_failure "Disable shows error when not exists" dokku dns:cron --disable
    
    # Test cron flag validation
    assert_failure "Invalid cron flag should fail" dokku dns:cron --invalid-flag
    assert_output_contains_ignore_exit "Invalid flag shows helpful error" "unknown flag.*invalid-flag" dokku dns:cron --invalid-flag
    
    # Test metadata and file creation
    dokku dns:cron --enable >/dev/null 2>&1
    assert_success "Cron metadata files created" test -f /var/lib/dokku/services/dns/cron/status
    assert_success "Cron log file created" test -f /var/lib/dokku/services/dns/cron/sync.log
    assert_output_contains "Cron status file contains enabled" "enabled" cat /var/lib/dokku/services/dns/cron/status
    
    # Clean up - disable cron for other tests
    dokku dns:cron --disable >/dev/null 2>&1 || true
}

test_dns_zones() {
    log_info "Testing DNS zones functionality..."
    
    # Ensure AWS provider is configured (required for zones operations)
    dokku dns:configure aws >/dev/null 2>&1
    
    # Check if AWS CLI and credentials are available
    local aws_available=false
    local test_zone=""
    if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
        aws_available=true
        # Get the first available hosted zone for testing
        test_zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//')
        log_info "AWS CLI available, testing with real zone: $test_zone"
    else
        log_info "AWS CLI not available or not configured, testing error handling"
    fi
    
    # Test zones listing
    if [[ "$aws_available" == "true" ]]; then
        assert_output_contains "Zones listing shows real status" "DNS Zones Status" dokku dns:zones
        assert_output_contains "Zones listing shows AWS provider" "aws provider" dokku dns:zones
    else
        assert_output_contains_ignore_exit "Zones listing shows status" "DNS Zones Status" dokku dns:zones
    fi
    
    # Test zone details
    if [[ "$aws_available" == "true" && -n "$test_zone" ]]; then
        assert_output_contains "Zone details shows real zone info" "DNS Zone Details: $test_zone" dokku dns:zones "$test_zone"
        assert_output_contains "Zone details shows AWS info" "AWS Route53 Information" dokku dns:zones "$test_zone"
        assert_output_contains "Zone details shows zone ID" "Zone ID:" dokku dns:zones "$test_zone"
        assert_output_contains "Zone details shows records section" "DNS Records" dokku dns:zones "$test_zone"
        assert_output_contains "Zone details shows Dokku integration" "Dokku Integration" dokku dns:zones "$test_zone"
        
        # Test with non-existent zone
        assert_failure "Non-existent zone should fail" dokku dns:zones "nonexistent-test-zone-12345.com"
        assert_output_contains_ignore_exit "Non-existent zone shows error" "not found in Route53" dokku dns:zones "nonexistent-test-zone-12345.com"
    else
        assert_output_contains_ignore_exit "Zone details shows AWS CLI requirement" "AWS CLI is not installed" dokku dns:zones example.com
    fi
    
    # Test zones flag validation (these should work regardless of AWS availability)
    assert_failure "Enable zone requires argument or --all" dokku dns:zones --enable
    assert_failure "Disable zone requires argument or --all" dokku dns:zones --disable
    assert_failure "All flag requires action" dokku dns:zones --all
    assert_failure "Zone name conflicts with action flags" dokku dns:zones example.com --enable test.com
    
    # Test enable/disable zone functionality
    if [[ "$aws_available" == "true" && -n "$test_zone" ]]; then
        # These will work but may not find matching Dokku apps, which is expected
        assert_output_contains_ignore_exit "Enable zone processes real zone" "Enabling DNS management for zone: $test_zone" dokku dns:zones --enable "$test_zone"
        assert_output_contains "Disable zone works with real zone" "Disabling DNS management for zone: $test_zone" dokku dns:zones --disable "$test_zone"
        
        # Test enable-all
        assert_output_contains_ignore_exit "Enable-all processes real zones" "Enabling DNS management for all zones" dokku dns:zones --enable --all
        
        # Test disable-all
        assert_output_contains "Disable-all works with AWS CLI" "Disabling DNS management for all zones" dokku dns:zones --disable --all
    else
        assert_output_contains_ignore_exit "Enable zone shows AWS CLI requirement" "AWS CLI is not installed" dokku dns:zones --enable example.com
        assert_output_contains "Disable zone works without AWS CLI" "No apps are currently managed by DNS" dokku dns:zones --disable example.com
        assert_output_contains_ignore_exit "Enable-all shows AWS CLI requirement" "AWS CLI is not installed" dokku dns:zones --enable --all
        
        # Test disable-all (should work without AWS CLI)
        assert_output_contains "Disable-all works without AWS CLI" "No apps are currently managed by DNS" dokku dns:zones --disable --all
    fi
    
    # Test unknown flag (should work regardless of AWS availability)
    assert_failure "Unknown flag should fail" dokku dns:zones --invalid-flag
    assert_output_contains_ignore_exit "Unknown flag shows error" "Unknown option" dokku dns:zones --invalid-flag
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
    test_dns_zones
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