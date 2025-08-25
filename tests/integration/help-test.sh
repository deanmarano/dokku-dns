#!/usr/bin/env bash
set -euo pipefail

# DNS Plugin Help and Version Integration Tests
# Tests: 4 integration tests for help and version commands
# Expected: 4 passing, 0 failing

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

# Test suite for DNS help and version commands
test_dns_help() {
    log_info "Testing DNS help commands..."
    
    assert_output_contains "Main help shows usage" "usage:" dokku dns:help
    assert_output_contains "Main help shows available commands" "dns:apps:enable" dokku dns:help
    assert_output_contains "Add help works" "enable DNS management for an application" dokku dns:help apps:enable
    assert_output_contains "Version shows plugin version" "dokku-dns plugin version" dokku dns:version
}

# Main test execution
main() {
    echo -e "${BLUE}🧪 DNS Plugin Help and Version Tests${NC}"
    echo "========================================"
    
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
    
    # Run test suites
    test_dns_help
    
    # Results
    echo
    echo "========================================"
    echo -e "${BLUE}📊 Test Results${NC}"
    echo "========================================"
    echo -e "Total tests: ${TESTS_TOTAL}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}🎉 All help and version tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}💥 Some help and version tests failed.${NC}"
        exit 1
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi