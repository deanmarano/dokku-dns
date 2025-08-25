#!/usr/bin/env bash
set -euo pipefail

# Unified Docker-based DNS plugin testing script
# This is a wrapper that calls the integration test orchestrator with enhanced logging
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

# Enhanced result reporting
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✅ Docker tests completed successfully!" | tee -a "$LOG_FILE"
    
    # Extract and display test summary if available
    echo "" | tee -a "$LOG_FILE"
    echo "=== 🔍 Quick Test Summary ===" | tee -a "$LOG_FILE"
    if grep -q "📊 Test Results" "$LOG_FILE"; then
        # Extract the formal test summary
        grep -A10 "📊 Test Results" "$LOG_FILE" | grep -E "(Total tests|Passed|Failed|All tests)" | tail -4 | tee -a "$LOG_FILE"
    else
        # Fallback count
        local passed_count
        passed_count=$(grep -o "✅" "$LOG_FILE" | wc -l | tr -d ' ')
        echo "✅ Tests passed: $passed_count" | tee -a "$LOG_FILE"
    fi
else
    echo "❌ Docker tests failed!" | tee -a "$LOG_FILE"
    echo "📝 Full log available at: $LOG_FILE" | tee -a "$LOG_FILE"
    
    # Show failure summary
    echo "" | tee -a "$LOG_FILE"
    echo "=== ⚠️  Failure Summary ===" | tee -a "$LOG_FILE"
    local failure_count
    failure_count=$(grep "❌" "$LOG_FILE" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" | wc -l | tr -d ' ')
    if [[ "$failure_count" -gt 0 ]]; then
        echo "❌ Failed tests: $failure_count" | tee -a "$LOG_FILE"
        echo "Recent failures:" | tee -a "$LOG_FILE"
        grep "❌" "$LOG_FILE" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" | tail -5 | tee -a "$LOG_FILE"
    else
        echo "No specific test failures found. Check full log for details." | tee -a "$LOG_FILE"
    fi
    
    echo "" | tee -a "$LOG_FILE"
    echo "💡 Troubleshooting tips:" | tee -a "$LOG_FILE"
    echo "   • View detailed results: scripts/view-test-log.sh --parse" | tee -a "$LOG_FILE"
    echo "   • Follow test execution: scripts/view-test-log.sh --follow" | tee -a "$LOG_FILE"
    echo "   • View last 50 lines: scripts/view-test-log.sh --tail" | tee -a "$LOG_FILE"
fi

exit "$EXIT_CODE"