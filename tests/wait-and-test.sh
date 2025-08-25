#!/usr/bin/env bash
set -euo pipefail

# Wait-and-test script for Docker Compose orchestrated testing
# This script waits for the Dokku container to be ready and then runs tests

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
MAX_WAIT_TIME=120  # Maximum wait time in seconds
WAIT_INTERVAL=5    # Check interval in seconds

log "INFO" "Starting wait-and-test orchestration..."
log "INFO" "Target Dokku host: $DOKKU_HOST:$DOKKU_SSH_PORT"
log "INFO" "Test app: $TEST_APP"

# Function to check if Dokku is ready
check_dokku_ready() {
    # Try to connect via netcat first (basic connectivity)
    if ! nc -z "$DOKKU_HOST" "$DOKKU_SSH_PORT" >/dev/null 2>&1; then
        return 1
    fi
    
    # Try to run a simple dokku command via SSH (if SSH is configured)
    # For now, just check if the port is open
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

# Now run the integration tests using the consolidated test script in direct mode
log "INFO" "Running integration tests in direct mode..."

# Use the consolidated test script in direct mode - fix path for container environment
TEST_SCRIPT="/plugin/scripts/test-docker.sh"

if [[ ! -f "$TEST_SCRIPT" ]]; then
    log "ERROR" "Consolidated test script not found: $TEST_SCRIPT"
    log "INFO" "Available files in /plugin/scripts/:"
    ls -la /plugin/scripts/ || log "WARNING" "Could not list scripts directory"
    exit 1
fi

# Execute the consolidated test script in direct mode
log "INFO" "Executing consolidated test script..."
if "$TEST_SCRIPT" --direct; then
    log "SUCCESS" "All tests completed successfully!"
    exit 0
else
    log "ERROR" "Tests failed!"
    exit 1
fi