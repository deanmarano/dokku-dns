#!/usr/bin/env bash
# Install git hooks for dokku-dns plugin development

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "🔧 Installing git hooks for dokku-dns plugin..."

# Install pre-commit hook
echo "Installing pre-commit hook..."
cp "$SCRIPT_DIR/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ Git hooks installed successfully!"
echo ""
echo "The pre-commit hook will:"
echo "  • Run shellcheck linting on all code changes"
echo "  • Run Docker unit tests by default (fast)"
echo "  • Skip tests for documentation-only changes"
echo ""
echo "To customize behavior:"
echo "  • Skip all tests: SKIP_TESTS=1 git commit"
echo "  • Skip Docker tests: RUN_DOCKER_TESTS=0 git commit"
echo "  • Run integration tests: RUN_INTEGRATION_TESTS=1 git commit"
echo ""
echo "To uninstall hooks:"
echo "  rm $HOOKS_DIR/pre-commit"
