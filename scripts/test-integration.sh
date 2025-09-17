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
  output=$("$@" 2>&1) || true # Ignore exit code
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

# Main test execution
main() {
  echo -e "${BLUE}🧪 DNS Plugin Integration Tests${NC}"
  echo "=================================="

  # Check if we're in a Dokku environment
  if ! command -v dokku >/dev/null 2>&1; then
    log_error "Dokku not found. Please run these tests in a Dokku environment."
    exit 1
  fi

  # Check if DNS plugin is available, install if not
  if ! dokku help | grep -q dns; then
    log_info "DNS plugin not found. Attempting to install from mounted source..."

    # Install the plugin from the mounted directory (different paths in different environments)
    local plugin_source=""
    if [[ -d "/tmp/dokku-dns" ]]; then
      plugin_source="/tmp/dokku-dns"
    elif [[ -d "/plugin" ]]; then
      plugin_source="/plugin"
    fi

    if [[ -n "$plugin_source" ]]; then
      log_info "Installing DNS plugin from $plugin_source..."

      # Copy plugin to dokku plugins directory and install
      dokku plugin:install "file://$plugin_source" dns || {
        log_error "Failed to install DNS plugin from mounted directory"

        # Try alternative installation method for Docker environment
        log_info "Attempting manual plugin installation..."
        if command -v docker >/dev/null 2>&1; then
          # We're in a Docker environment, try copying directly to dokku container
          docker exec dokku-local mkdir -p /var/lib/dokku/plugins/available/dns 2>/dev/null || true
          docker cp "$plugin_source/." dokku-local:/var/lib/dokku/plugins/available/dns/ 2>/dev/null || true
          docker exec dokku-local dokku plugin:enable dns 2>/dev/null || true
        fi

        # Final check
        if ! dokku help | grep -q dns; then
          log_error "All DNS plugin installation methods failed"
          exit 1
        else
          log_success "DNS plugin successfully installed via manual method"
        fi
      }
      log_success "DNS plugin installed successfully"
    else
      log_error "DNS plugin source not found at /tmp/dokku-dns or /plugin"
      log_error "Please ensure the plugin source is mounted correctly"
      exit 1
    fi
  else
    log_success "DNS plugin is already available"
  fi

  # Setup
  setup_test_environment

  # All test suites have been moved to BATS integration tests:
  # - Help tests: tests/integration/help-integration.bats
  # - Apps tests: tests/integration/apps-integration.bats
  # - Zones tests: tests/integration/zones-integration.bats
  # - Cron tests: tests/integration/cron-integration.bats
  # - Provider tests: tests/integration/providers-integration.bats
  # - Trigger tests: tests/integration/triggers-integration.bats

  log_info "All integration tests have been extracted to BATS framework"
  log_info "This script now serves as a placeholder and test environment setup"

  # Cleanup
  cleanup_test_environment

  # Results
  echo
  echo "=================================="
  echo -e "${BLUE}📊 Integration Test Status${NC}"
  echo "=================================="
  echo -e "${GREEN}✅ Test environment setup completed successfully${NC}"
  echo -e "${BLUE}ℹ️  All integration tests now run via BATS framework${NC}"
  echo -e "${BLUE}ℹ️  Run 'bats tests/integration/*.bats' to execute tests${NC}"

  exit 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
