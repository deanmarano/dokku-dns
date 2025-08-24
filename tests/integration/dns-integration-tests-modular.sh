#!/usr/bin/env bash
# DNS Plugin Modular Integration Tests
# Main orchestrator for running all test suites together or individually

set -euo pipefail

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Load all test suite modules
source "$SCRIPT_DIR/core-commands.sh"
source "$SCRIPT_DIR/cron-functionality.sh" 
source "$SCRIPT_DIR/zones-management.sh"
source "$SCRIPT_DIR/sync-operations.sh"
source "$SCRIPT_DIR/error-handling.sh"

usage() {
    echo "Usage: $0 [OPTIONS] [TEST_SUITE]"
    echo ""
    echo "Run DNS plugin integration tests in modular fashion"
    echo ""
    echo "TEST_SUITE options:"
    echo "  all             Run all test suites (default)"
    echo "  core            Run core commands tests"
    echo "  cron            Run cron functionality tests"
    echo "  zones           Run zones management tests"
    echo "  sync            Run sync operations tests"
    echo "  errors          Run error handling tests"
    echo ""
    echo "OPTIONS:"
    echo "  --help          Show this help message"
    echo "  --list          List available test suites"
    echo "  --setup-only    Only run setup, don't run tests"
    echo ""
    echo "Examples:"
    echo "  $0                    # Run all tests"
    echo "  $0 core              # Run only core commands tests"
    echo "  $0 cron              # Run only cron functionality tests"
}

list_test_suites() {
    echo "Available test suites:"
    echo "  ✅ core-commands      - Basic help, configure, verify, enable, sync, disable"
    echo "  ✅ cron-functionality  - Cron status, enable, disable, schedules, metadata"
    echo "  ✅ zones-management    - Zone listing, zone-aware reports and sync"
    echo "  ✅ sync-operations     - Sync-all functionality and bulk operations"
    echo "  ✅ error-handling      - Edge cases, invalid inputs, version/help commands"
}

setup_test_environment() {
    log_remote "INFO" "🚀 Setting up DNS Plugin Test Environment"
    
    # Install DNS plugin
    install_dns_plugin
    
    # Setup AWS credentials
    setup_aws_credentials
    
    # Load report assertion functions
    load_report_assertions
    
    log_remote "SUCCESS" "✅ Test environment setup complete"
}

run_test_suite() {
    local suite="$1"
    local suite_result=0
    
    case "$suite" in
        "core"|"core-commands")
            run_core_commands_tests || suite_result=1
            ;;
        "cron"|"cron-functionality")
            run_cron_functionality_tests || suite_result=1
            ;;
        "zones"|"zones-management")
            run_zones_management_tests || suite_result=1
            ;;
        "sync"|"sync-operations")
            run_sync_operations_tests || suite_result=1
            ;;
        "errors"|"error-handling")
            run_error_handling_tests || suite_result=1
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
    
    local overall_result=0
    local suites=("core-commands" "cron-functionality" "zones-management" "sync-operations" "error-handling")
    local passed_suites=()
    local failed_suites=()
    
    for suite in "${suites[@]}"; do
        echo ""
        log_remote "INFO" "📋 Starting test suite: $suite"
        
        if run_test_suite "$suite"; then
            passed_suites+=("$suite")
            log_remote "SUCCESS" "✅ Test suite '$suite' PASSED"
        else
            failed_suites+=("$suite")
            log_remote "ERROR" "❌ Test suite '$suite' FAILED"
            overall_result=1
        fi
    done
    
    # Print summary
    echo ""
    echo "===================================="
    echo "📊 Test Results Summary"
    echo "===================================="
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
            all|core|cron|zones|sync|errors|core-commands|cron-functionality|zones-management|sync-operations|error-handling)
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