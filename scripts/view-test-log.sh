#!/usr/bin/env bash
set -euo pipefail

# View the latest Docker test log
# Usage: scripts/view-test-log.sh [--tail] [--follow]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../tmp/test-results"

if [[ ! -d "$LOG_DIR" ]]; then
    echo "❌ No test logs directory found: $LOG_DIR"
    echo "   Run tests first with: scripts/test-docker.sh"
    exit 1
fi

# Find the latest log file
LATEST_LOG=$(find "$LOG_DIR" -name "docker-tests-*.log" -type f -exec ls -t {} + | head -1)

if [[ -z "$LATEST_LOG" ]]; then
    echo "❌ No test log files found in: $LOG_DIR"
    echo "   Run tests first with: scripts/test-docker.sh"
    exit 1
fi

echo "📝 Viewing latest test log: $LATEST_LOG"
echo ""

case "${1:-}" in
    --tail)
        tail -50 "$LATEST_LOG"
        ;;
    --follow)
        tail -f "$LATEST_LOG"
        ;;
    *)
        cat "$LATEST_LOG"
        ;;
esac