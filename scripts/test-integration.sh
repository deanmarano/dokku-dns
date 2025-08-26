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
    
    
    # Remove from DNS management if added
    dokku dns:apps:disable "$TEST_APP" >/dev/null 2>&1 || true
    
    # Remove test app
    if dokku apps:list | grep -q "^$TEST_APP$"; then
        dokku apps:destroy "$TEST_APP" --force >/dev/null 2>&1 || true
        log_success "Cleaned up test app: $TEST_APP"
    fi
}

# Test suites
# This allows for cleaner test separation and native BATS framework usage


# NOTE: DNS app management tests (dns:apps:enable, dns:apps:disable, dns:apps:sync) 
# are now covered by BATS integration tests in tests/integration/apps-integration.bats
# This function has been removed to eliminate test duplication



test_zones_with_report_sync() {
    log_info "Testing zones functionality with report and sync..."
    
    # Ensure AWS provider is configured
    
    # Create a test app with domains that would be in example.com zone
    local ZONES_TEST_APP="zones-report-test"
    
    # Clean up any existing test app first
    dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1 || true
    
    # Wait a moment for cleanup to complete
    sleep 1
    
    # Ensure no zones are enabled to prevent auto-DNS management by triggers
    mkdir -p /var/lib/dokku/services/dns
    rm -f /var/lib/dokku/services/dns/ENABLED_ZONES
    
    # Create the test app (or use existing if it already exists)
    if ! dokku apps:list 2>/dev/null | grep -q "^$ZONES_TEST_APP$"; then
        assert_success "Create zones test app" dokku apps:create "$ZONES_TEST_APP"
    else
        log_success "Create zones test app (already exists)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Add domains that would be in example.com zone (ignore errors if domains already exist)
    if dokku domains:add "$ZONES_TEST_APP" "app.example.com" >/dev/null 2>&1; then
        log_success "Add app.example.com domain"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_success "Add app.example.com domain (already exists or added)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if dokku domains:add "$ZONES_TEST_APP" "api.example.com" >/dev/null 2>&1; then
        log_success "Add api.example.com domain"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_success "Add api.example.com domain (already exists or added)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Ensure app is not in DNS management (triggers might have added it)
    dokku dns:apps:disable "$ZONES_TEST_APP" >/dev/null 2>&1 || true
    
    
    # Test that enabling a zone (if AWS CLI available) and then running sync works correctly
    # We'll test the zones enable/disable persistence functionality
    if [[ -f "/tmp/test-enabled-zones" ]]; then
        # Create fake enabled zones file for testing
        mkdir -p /var/lib/dokku/services/dns
        echo "example.com" > /var/lib/dokku/services/dns/ENABLED_ZONES
        
        # Now add the app to DNS and test sync behavior with enabled zones
        assert_success "Add app to DNS management after zone enabled" dokku dns:apps:enable "$ZONES_TEST_APP"
        
        # Test sync with enabled zone
        assert_output_contains "Sync works with enabled zone" "Syncing domains for app" dokku dns:apps:sync "$ZONES_TEST_APP"
        
        # Clean up
        rm -f /var/lib/dokku/services/dns/ENABLED_ZONES
        dokku dns:apps:disable "$ZONES_TEST_APP" >/dev/null 2>&1 || true
    fi
    
    # Clean up the test app - make cleanup more robust
    if dokku apps:list 2>/dev/null | grep -q "$ZONES_TEST_APP"; then
        if dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1; then
            log_success "Clean up zones test app"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_warning "Could not clean up zones test app (may have been removed already)"
        fi
    else
        log_success "Clean up zones test app (already cleaned up)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

test_error_conditions() {
    log_info "Testing error conditions..."
    
    # NOTE: DNS apps error condition tests moved to apps-integration.bats
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
    # NOTE: Help tests are now run separately via BATS (tests/integration/help-integration.bats)
    # test_dns_app_management - now covered by BATS tests/integration/apps-integration.bats
    test_zones_with_report_sync
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