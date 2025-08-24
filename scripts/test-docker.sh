#!/usr/bin/env bash
set -euo pipefail

# Unified Docker-based DNS plugin testing script
# This is a wrapper that calls the modular integration test orchestrator
# Usage: scripts/test-docker.sh [--build] [--logs] [--direct] [TEST_SUITE]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ORCHESTRATOR="$SCRIPT_DIR/../tests/integration/docker-orchestrator.sh"
LOG_DIR="$SCRIPT_DIR/../tmp/test-results"
LOG_FILE="$LOG_DIR/docker-tests-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

# Check if the orchestrator exists
if [[ ! -f "$ORCHESTRATOR" ]]; then
    echo "❌ Integration test orchestrator not found: $ORCHESTRATOR" | tee -a "$LOG_FILE"
    echo "   Make sure tests/integration/docker-orchestrator.sh exists" | tee -a "$LOG_FILE"
    exit 1
fi

echo "🚀 Starting Docker tests with logging..." | tee -a "$LOG_FILE"
echo "📝 Log file: $LOG_FILE" | tee -a "$LOG_FILE"
echo "⏰ Started at: $(date)" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Run the orchestrator with logging
set +e  # Don't exit on error so we can capture exit code
"$ORCHESTRATOR" "$@" 2>&1 | tee -a "$LOG_FILE"
EXIT_CODE=${PIPESTATUS[0]}
set -e

echo "" | tee -a "$LOG_FILE"
echo "⏰ Completed at: $(date)" | tee -a "$LOG_FILE"
echo "📊 Exit code: $EXIT_CODE" | tee -a "$LOG_FILE"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Docker tests completed successfully!" | tee -a "$LOG_FILE"
else
    echo "❌ Docker tests failed!" | tee -a "$LOG_FILE"
    echo "📝 Full log available at: $LOG_FILE"
fi

exit $EXIT_CODE