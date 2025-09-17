#!/usr/bin/env bash
set -euo pipefail

# Enhanced Docker container test runner
# Incorporates BATS installation and execution logic from scripts/test-docker.sh
# This runs inside the test-runner container

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  local level="$1"
  shift
  local message="$*"

  case "$level" in
    "INFO")
      echo -e "${BLUE}[INFO]${NC} $message"
      ;;
    "SUCCESS")
      echo -e "${GREEN}[SUCCESS]${NC} $message"
      ;;
    "WARNING")
      echo -e "${YELLOW}[WARNING]${NC} $message"
      ;;
    "ERROR")
      echo -e "${RED}[ERROR]${NC} $message"
      ;;
  esac
}

# Configuration
DOKKU_HOST="${DOKKU_HOST:-dokku}"
DOKKU_SSH_PORT="${DOKKU_SSH_PORT:-22}"
DOKKU_USER="${DOKKU_USER:-dokku}"
TEST_APP="${TEST_APP:-nextcloud}"
MAX_WAIT_TIME=120 # Maximum wait time in seconds
WAIT_INTERVAL=5   # Check interval in seconds

log "INFO" "Starting enhanced container test orchestration..."
log "INFO" "Target Dokku host: $DOKKU_HOST:$DOKKU_SSH_PORT"
log "INFO" "Test app: $TEST_APP"

# Function to check if Dokku is ready
check_dokku_ready() {
  # Try to connect via netcat first (basic connectivity)
  if ! nc -z "$DOKKU_HOST" "$DOKKU_SSH_PORT" >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Wait for Dokku to be ready
log "INFO" "Waiting for Dokku container to be ready..."
elapsed_time=0

while ! check_dokku_ready; do
  if [[ $elapsed_time -ge $MAX_WAIT_TIME ]]; then
    log "ERROR" "Timeout waiting for Dokku container to be ready after ${MAX_WAIT_TIME}s"
    exit 1
  fi

  log "INFO" "Dokku not ready yet, waiting ${WAIT_INTERVAL}s... (${elapsed_time}/${MAX_WAIT_TIME}s)"
  sleep $WAIT_INTERVAL
  elapsed_time=$((elapsed_time + WAIT_INTERVAL))
done

log "SUCCESS" "Dokku container is ready!"

# Give it a bit more time to fully initialize
log "INFO" "Giving Dokku additional time to fully initialize..."
sleep 10

# Install BATS for integration tests
log "INFO" "Installing BATS for integration testing..."
if command -v bats >/dev/null 2>&1; then
  log "INFO" "BATS already installed"
else
  # Install BATS
  if apt-get update -qq &&
    git clone https://github.com/bats-core/bats-core.git /tmp/bats &&
    cd /tmp/bats &&
    ./install.sh /usr/local &&
    rm -rf /tmp/bats; then
    log "SUCCESS" "BATS installed successfully"
  else
    log "WARNING" "Failed to install BATS, will skip BATS integration tests"
  fi
fi

# Run main integration tests
log "INFO" "Running main integration tests..."
main_tests_passed=false
if [[ -f "/plugin/scripts/test-integration.sh" ]]; then
  if "/plugin/scripts/test-integration.sh"; then
    log "SUCCESS" "Main integration tests passed"
    main_tests_passed=true
  else
    log "ERROR" "Main integration tests failed"
  fi
else
  log "ERROR" "Main integration test script not found: /plugin/scripts/test-integration.sh"
fi

# Run BATS integration tests if available
log "INFO" "Running BATS integration tests..."
bats_tests_passed=true
bats_tests_found=false

# Find and run all BATS integration test files
if command -v bats >/dev/null 2>&1; then
  # Change to plugin directory for proper relative paths
  cd /plugin

  # Find all .bats files in tests/integration/
  if compgen -G "tests/integration/*.bats" >/dev/null; then
    bats_tests_found=true
    log "INFO" "Found BATS integration tests, executing..."

    for bats_file in tests/integration/*.bats; do
      log "INFO" "Running BATS test: $bats_file"
      if bats "$bats_file"; then
        log "SUCCESS" "BATS test passed: $bats_file"
      else
        log "ERROR" "BATS test failed: $bats_file"
        bats_tests_passed=false
      fi
    done
  else
    log "INFO" "No BATS integration test files found in tests/integration/"
  fi
else
  log "WARNING" "BATS not available, skipping BATS integration tests"
fi

# Overall result
log "INFO" "Test execution summary:"
log "INFO" "- Main integration tests: $([ "$main_tests_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")"
if [[ "$bats_tests_found" = true ]]; then
  log "INFO" "- BATS integration tests: $([ "$bats_tests_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")"
else
  log "INFO" "- BATS integration tests: ⏭️ SKIPPED (no tests found)"
fi

if [[ "$main_tests_passed" = true ]] && [[ "$bats_tests_passed" = true ]]; then
  log "SUCCESS" "All tests completed successfully!"
  exit 0
else
  log "ERROR" "Some tests failed!"
  exit 1
fi
