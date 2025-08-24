#!/usr/bin/env bash
# DNS Plugin Modular Integration Tests
# Main orchestrator for running all test suites together or individually

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Load all test suite modules
source "$SCRIPT_DIR/apps-test.sh"
source "$SCRIPT_DIR/providers-test.sh"
source "$SCRIPT_DIR/report-test.sh"
source "$SCRIPT_DIR/cron-test.sh" 
source "$SCRIPT_DIR/zones-test.sh"
source "$SCRIPT_DIR/sync-all-test.sh"
source "$SCRIPT_DIR/version-test.sh"

usage() {
    echo "Usage: $0 [OPTIONS] [TEST_SUITE]"
    echo ""
    echo "Run DNS plugin integration tests"
    echo ""
    echo "TEST_SUITE options:"
    echo "  all             Run all test suites (default)"
    echo "  apps            Run apps subcommand tests"
    echo "  providers       Run providers subcommand tests"
    echo "  report          Run report subcommand tests"
    echo "  cron            Run cron subcommand tests"
    echo "  zones           Run zones subcommand tests"
    echo "  sync-all        Run sync-all subcommand tests"
    echo "  version         Run version subcommand tests"
    echo ""
    echo "OPTIONS:"
    echo "  --help          Show this help message"
    echo "  --list          List available test suites"
    echo "  --setup-only    Only run setup, don't run tests"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 apps              # Run only apps subcommand tests"
    echo "  $0 providers         # Run only providers subcommand tests"
    echo "  $0 report            # Run only report subcommand tests"
    echo "  $0 cron              # Run only cron subcommand tests"
}

list_test_suites() {
    echo "Available test suites:"
    echo "  ✅ apps-test          - Apps subcommand: help, enable, disable, sync"
    echo "  ✅ providers-test     - Providers subcommand: configure, verify, AWS authentication"
    echo "  ✅ report-test        - Report subcommand: global and app-specific reporting"
    echo "  ✅ cron-test          - Cron subcommand: status, enable, disable, schedules"
    echo "  ✅ zones-test         - Zones subcommand: listing, zone-aware reports and sync"
    echo "  ✅ sync-all-test      - Sync-all subcommand: bulk operations and functionality"
    echo "  ✅ version-test       - Version subcommand: edge cases, invalid inputs, help"
}

setup_test_environment() {
    log_remote "INFO" "🚀 Setting up DNS Plugin Test Environment"
    
    # Install DNS plugin
    install_dns_plugin
    
    # Setup AWS credentials
    setup_aws_credentials
    
    log_remote "SUCCESS" "✅ Test environment setup complete"
}

run_test_suite() {
    local suite="$1"
    local suite_result=0
    
    case "$suite" in
        "apps"|"apps-test")
            run_apps_tests || suite_result=1
            ;;
        "providers"|"providers-test")
            run_providers_tests || suite_result=1
            ;;
        "report"|"report-test")
            run_report_tests || suite_result=1
            ;;
        "cron"|"cron-test")
            run_cron_tests || suite_result=1
            ;;
        "zones"|"zones-test")
            run_zones_tests || suite_result=1
            ;;
        "sync-all"|"sync-all-test")
            run_sync_all_tests || suite_result=1
            ;;
        "version"|"version-test")
            run_version_tests || suite_result=1
            ;;
        *)
            echo "❌ Unknown test suite: $suite"
            return 1
            ;;
    esac
    
    return $suite_result
}

run_all_tests() {
    log_remote "INFO" "🧪 Running All DNS Plugin Integration Test Suites"
    
    # Reset test counts
    reset_test_counts
    
    local overall_result=0
    local suites=("apps-test" "providers-test" "report-test" "cron-test" "zones-test" "sync-all-test" "version-test")
    local passed_suites=()
    local failed_suites=()
    
    for suite in "${suites[@]}"; do
        echo ""
        log_remote "INFO" "📋 Starting test suite: $suite"
        
        # Capture test output and count individual tests
        local suite_output
        suite_output=$(run_test_suite "$suite" 2>&1)
        local suite_result=$?
        
        # Count individual tests from output
        local passed_count
        local failed_count
        passed_count=$(echo "$suite_output" | grep -c "✓")
        failed_count=$(echo "$suite_output" | grep -c "❌")
        
        # Update global counters
        PASSED_TESTS=$((PASSED_TESTS + passed_count))
        FAILED_TESTS=$((FAILED_TESTS + failed_count))
        TOTAL_TESTS=$((TOTAL_TESTS + passed_count + failed_count))
        
        # Print the captured output
        echo "$suite_output"
        
        if [[ $suite_result -eq 0 ]]; then
            passed_suites+=("$suite")
            log_remote "SUCCESS" "✅ Test suite '$suite' PASSED ($passed_count✓ $failed_count❌)"
        else
            failed_suites+=("$suite")
            log_remote "ERROR" "❌ Test suite '$suite' FAILED ($passed_count✓ $failed_count❌)"
            overall_result=1
        fi
    done
    
    # Print summary
    echo ""
    echo "===================================="
    echo "📊 Individual Test Results Summary"
    echo "===================================="
    echo "Total: $TOTAL_TESTS | Passed: $PASSED_TESTS | Failed: $FAILED_TESTS"
    echo ""
    echo "Test Suite Results:"
    echo "Total test suites: ${#suites[@]}"
    echo "✅ Passed: ${#passed_suites[@]}"
    echo "❌ Failed: ${#failed_suites[@]}"
    
    if [[ ${#passed_suites[@]} -gt 0 ]]; then
        echo ""
        echo "✅ Passed suites:"
        for suite in "${passed_suites[@]}"; do
            echo "  - $suite"
        done
    fi
    
    if [[ ${#failed_suites[@]} -gt 0 ]]; then
        echo ""
        echo "❌ Failed suites:"
        for suite in "${failed_suites[@]}"; do
            echo "  - $suite"
        done
    fi
    
    if [[ $overall_result -eq 0 ]]; then
        log_remote "SUCCESS" "🎉 All DNS plugin integration tests completed successfully!"
    else
        log_remote "ERROR" "💥 Some DNS plugin integration tests failed!"
    fi
    
    return $overall_result
}

main() {
    local test_suite="all"
    local setup_only=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                usage
                exit 0
                ;;
            --list)
                list_test_suites
                exit 0
                ;;
            --setup-only)
                setup_only=true
                shift
                ;;
            all|apps|providers|report|cron|zones|sync-all|version|apps-test|providers-test|report-test|cron-test|zones-test|sync-all-test|version-test)
                test_suite="$1"
                shift
                ;;
            *)
                echo "❌ Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Setup test environment
    setup_test_environment
    
    if [[ "$setup_only" == "true" ]]; then
        log_remote "INFO" "Setup complete - exiting as requested"
        exit 0
    fi
    
    # Run tests
    if [[ "$test_suite" == "all" ]]; then
        run_all_tests
    else
        log_remote "INFO" "🧪 Running test suite: $test_suite"
        run_test_suite "$test_suite"
    fi
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi