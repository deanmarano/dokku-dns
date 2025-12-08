#!/usr/bin/env bash
# Common library for manual testing scripts
#
# This library provides utilities for running manual tests documented in TESTING.md
# as automated, scriptable test procedures.

set -eo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test log file
TEST_LOG="${TEST_LOG:-/tmp/dokku-dns-manual-tests-$(date +%Y%m%d-%H%M%S).log}"

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$TEST_LOG"
}

log_success() {
  echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$TEST_LOG"
}

log_error() {
  echo -e "${RED}[FAIL]${NC} $*" | tee -a "$TEST_LOG"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$TEST_LOG"
}

log_skip() {
  echo -e "${YELLOW}[SKIP]${NC} $*" | tee -a "$TEST_LOG"
}

# Test execution functions
test_start() {
  local test_name="$1"
  TESTS_RUN=$((TESTS_RUN + 1))
  log_info "Running: $test_name"
}

test_pass() {
  local test_name="$1"
  TESTS_PASSED=$((TESTS_PASSED + 1))
  log_success "$test_name"
}

test_fail() {
  local test_name="$1"
  local reason="$2"
  TESTS_FAILED=$((TESTS_FAILED + 1))
  log_error "$test_name"
  [[ -n "$reason" ]] && log_error "  Reason: $reason"
}

test_skip() {
  local test_name="$1"
  local reason="$2"
  TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
  log_skip "$test_name"
  [[ -n "$reason" ]] && log_skip "  Reason: $reason"
}

# Command execution with validation
run_command() {
  local description="$1"
  shift
  local cmd=("$@")

  log_info "  Executing: ${cmd[*]}"

  local output
  local exit_code=0

  if output=$("${cmd[@]}" 2>&1); then
    log_info "  Output: $output"
    echo "$output"
    return 0
  else
    exit_code=$?
    log_error "  Command failed with exit code $exit_code"
    log_error "  Output: $output"
    return $exit_code
  fi
}

# Validation functions
expect_success() {
  local description="$1"
  shift
  local cmd=("$@")

  if run_command "$description" "${cmd[@]}" >/dev/null; then
    return 0
  else
    return 1
  fi
}

expect_output_contains() {
  local description="$1"
  local expected="$2"
  shift 2
  local cmd=("$@")

  local output
  if output=$(run_command "$description" "${cmd[@]}"); then
    if echo "$output" | grep -q "$expected"; then
      log_info "  ✓ Output contains expected string: $expected"
      return 0
    else
      log_error "  ✗ Output does not contain expected string: $expected"
      log_error "  Actual output: $output"
      return 1
    fi
  else
    return 1
  fi
}

expect_no_error() {
  local description="$1"
  shift
  local cmd=("$@")

  local output
  if output=$(run_command "$description" "${cmd[@]}"); then
    if echo "$output" | grep -qiE "(error|fail|invalid)"; then
      log_error "  ✗ Output contains error indicators"
      log_error "  Output: $output"
      return 1
    else
      log_info "  ✓ No errors detected"
      return 0
    fi
  else
    return 1
  fi
}

# Provider validation
check_provider_available() {
  local provider="$1"

  log_info "Checking if $provider provider is configured..."

  if dokku dns:providers:verify "$provider" >/dev/null 2>&1; then
    log_success "$provider provider is available and configured"
    return 0
  else
    log_warn "$provider provider not configured or credentials invalid"
    return 1
  fi
}

# App management
create_test_app() {
  local app_name="$1"

  if dokku apps:list | grep -q "^$app_name$"; then
    log_info "Test app $app_name already exists"
    return 0
  fi

  if dokku apps:create "$app_name" >/dev/null 2>&1; then
    log_success "Created test app: $app_name"
    return 0
  else
    log_error "Failed to create test app: $app_name"
    return 1
  fi
}

cleanup_test_app() {
  local app_name="$1"

  if dokku apps:list | grep -q "^$app_name$"; then
    log_info "Cleaning up test app: $app_name"

    # Disable DNS management
    dokku dns:apps:disable "$app_name" >/dev/null 2>&1 || true

    # Destroy app
    if dokku apps:destroy "$app_name" --force >/dev/null 2>&1; then
      log_success "Cleaned up test app: $app_name"
      return 0
    else
      log_error "Failed to cleanup test app: $app_name"
      return 1
    fi
  fi
}

# Domain management
add_test_domain() {
  local app_name="$1"
  local domain="$2"

  if dokku domains:add "$app_name" "$domain" >/dev/null 2>&1; then
    log_success "Added domain $domain to $app_name"
    return 0
  else
    log_error "Failed to add domain $domain to $app_name"
    return 1
  fi
}

# DNS verification
verify_dns_record() {
  local domain="$1"
  local expected_ip="$2"
  local max_wait="${3:-60}"

  log_info "Verifying DNS record for $domain (expecting $expected_ip)"
  log_info "Waiting up to ${max_wait}s for DNS propagation..."

  local elapsed=0
  local interval=5

  while [[ $elapsed -lt $max_wait ]]; do
    local actual_ip
    if actual_ip=$(dig +short "$domain" @8.8.8.8 | head -1); then
      if [[ "$actual_ip" == "$expected_ip" ]]; then
        log_success "DNS record verified: $domain -> $actual_ip"
        return 0
      fi
    fi

    sleep $interval
    elapsed=$((elapsed + interval))
  done

  log_error "DNS record verification failed after ${max_wait}s"
  log_error "Expected: $expected_ip, Got: ${actual_ip:-<no response>}"
  return 1
}

# Get server IP
get_server_ip() {
  local ip
  if ip=$(curl -s ifconfig.me); then
    echo "$ip"
    return 0
  else
    log_error "Failed to get server IP"
    return 1
  fi
}

# Summary reporting
print_test_summary() {
  echo ""
  echo "========================================" | tee -a "$TEST_LOG"
  echo "Test Summary" | tee -a "$TEST_LOG"
  echo "========================================" | tee -a "$TEST_LOG"
  echo "Total tests:  $TESTS_RUN" | tee -a "$TEST_LOG"
  echo -e "${GREEN}Passed:       $TESTS_PASSED${NC}" | tee -a "$TEST_LOG"
  echo -e "${RED}Failed:       $TESTS_FAILED${NC}" | tee -a "$TEST_LOG"
  echo -e "${YELLOW}Skipped:      $TESTS_SKIPPED${NC}" | tee -a "$TEST_LOG"
  echo "========================================" | tee -a "$TEST_LOG"
  echo "Log file: $TEST_LOG" | tee -a "$TEST_LOG"
  echo ""

  if [[ $TESTS_FAILED -gt 0 ]]; then
    return 1
  else
    return 0
  fi
}

# Cleanup handler
cleanup_on_exit() {
  local exit_code=$?

  if [[ $exit_code -ne 0 ]]; then
    log_error "Tests exited with error code: $exit_code"
  fi

  print_test_summary

  exit $exit_code
}

# Set trap for cleanup
trap cleanup_on_exit EXIT
