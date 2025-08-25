#!/usr/bin/env bash
# Common test helpers for DNS plugin integration tests

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters - initialize if not already set
: "${TESTS_PASSED:=0}"
: "${TESTS_FAILED:=0}"
: "${TESTS_TOTAL:=0}"

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

# Environment checks
check_dokku_environment() {
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
}

# Test results summary
show_test_results() {
    local test_type="${1:-integration}"
    
    echo
    echo "========================================"
    echo -e "${BLUE}📊 Test Results${NC}"
    echo "========================================"
    echo -e "Total tests: ${TESTS_TOTAL}"
    echo -e "${GREEN}Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Failed: ${TESTS_FAILED}${NC}"
    
    if [ "$TESTS_FAILED" -eq 0 ]; then
        echo -e "${GREEN}🎉 All ${test_type} tests passed!${NC}"
        return 0
    else
        echo -e "${RED}💥 Some ${test_type} tests failed.${NC}"
        return 1
    fi
}