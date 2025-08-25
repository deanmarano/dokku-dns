#!/usr/bin/env bash
set -euo pipefail

# DNS Plugin Help and Version Integration Tests
# Tests: 4 integration tests for help and version commands
# Expected: 4 passing, 0 failing

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common test helpers
# shellcheck source=tests/integration/common.sh
source "$SCRIPT_DIR/common.sh"

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
    
    # Check environment using common helper
    check_dokku_environment
    
    # Run test suites
    test_dns_help
    
    # Show results using common helper
    show_test_results "help and version"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi