#!/usr/bin/env bash
set -euo pipefail

# Consolidated Docker-based DNS plugin testing script
# Combines orchestration and logging functionality in a single script
# Usage: scripts/test-docker.sh [--build] [--logs] [--direct] [TEST_SUITE]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/../tmp/test-results"
LOG_FILE="$LOG_DIR/docker-tests-$(date +%Y%m%d-%H%M%S).log"

# Create log directory
mkdir -p "$LOG_DIR"

show_help() {
    echo "Usage: $0 [--build] [--logs] [--direct] [TEST_FILE]"
    echo ""
    echo "Options:"
    echo "  --build    Force rebuild of Docker images"
    echo "  --logs     Show container logs after test completion"
    echo "  --direct   Run tests directly (skip Docker Compose orchestration)"
    echo "  --help     Show this help message"
    echo ""
    echo "Arguments:"
    echo "  TEST_FILE  Optional: specific test file to run (e.g., help-integration.bats)"
    echo "             If not specified, runs all integration tests"
    echo "             Special values:"
    echo "               --list           List available test suites"
    echo "               --summary        Run all tests and show detailed summary"
    echo ""
    echo "Environment variables:"
    echo "  AWS_ACCESS_KEY_ID      - AWS access key for Route53 testing"
    echo "  AWS_SECRET_ACCESS_KEY  - AWS secret key for Route53 testing"
    echo "  AWS_DEFAULT_REGION     - AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0 --build                                    # Full Docker Compose testing"
    echo "  AWS_ACCESS_KEY_ID=xxx $0 --logs               # With AWS credentials"
    echo "  $0 --direct                                   # Direct testing (containers must be running)"
    echo "  $0 --direct help-integration.bats             # Run only BATS help tests directly"
}

log_with_timestamp() {
    local message="$*"
    echo "$message" | tee -a "$LOG_FILE"
}

list_test_suites() {
    echo "📋 Available Test Suites:"
    echo ""
    echo "🧪 BATS Integration Tests:"
    if [[ -d "tests/integration" ]]; then
        find tests/integration -name "*.bats" -type f | sort | while read -r file; do
            local basename
            basename=$(basename "$file" .bats)
            local test_count
            test_count=$(grep -c "^@test" "$file" 2>/dev/null || echo "?")
            echo "   • ${basename} (${test_count} tests)"
        done
    fi
    echo ""
    echo "🔧 Legacy Integration Tests:"
    if [[ -f "scripts/test-integration.sh" ]]; then
        echo "   • test-integration.sh (setup/cleanup only)"
    fi
    echo ""
    echo "Usage Examples:"
    echo "   $0 --direct help-integration.bats     # Run only help tests"
    echo "   $0 --direct zones-integration.bats    # Run only zones tests"
    echo "   $0 --summary                          # Run all tests with summary"
}

run_test_suite_summary() {
    log_with_timestamp "🧪 Running comprehensive test suite with detailed summary..."
    
    # Initialize summary tracking
    local total_suites=0
    local passed_suites=0
    local failed_suites=0
    local total_tests=0
    local passed_tests=0
    local failed_tests=0
    
    # Array to store suite results
    declare -a suite_results
    
    # Run each BATS file individually for detailed tracking
    if [[ -d "tests/integration" ]]; then
        find tests/integration -name "*.bats" -type f | sort | while read -r bats_file; do
            local suite_name
            suite_name=$(basename "$bats_file" .bats)
            total_suites=$((total_suites + 1))
            
            log_with_timestamp ""
            log_with_timestamp "▶️  Running suite: $suite_name"
            
            if run_direct_tests "$bats_file"; then
                suite_results+=("✅ $suite_name")
                passed_suites=$((passed_suites + 1))
                log_with_timestamp "✅ Suite $suite_name completed successfully"
            else
                suite_results+=("❌ $suite_name")
                failed_suites=$((failed_suites + 1))
                log_with_timestamp "❌ Suite $suite_name failed"
            fi
        done
    fi
    
    # Generate comprehensive summary
    log_with_timestamp ""
    log_with_timestamp "═══════════════════════════════════════════"
    log_with_timestamp "📊 COMPREHENSIVE TEST SUITE SUMMARY"
    log_with_timestamp "═══════════════════════════════════════════"
    log_with_timestamp "Suite Results:"
    for result in "${suite_results[@]}"; do
        log_with_timestamp "   $result"
    done
    log_with_timestamp ""
    log_with_timestamp "📈 Overall Statistics:"
    log_with_timestamp "   • Total Suites: $total_suites"
    log_with_timestamp "   • Passed Suites: $passed_suites"
    log_with_timestamp "   • Failed Suites: $failed_suites"
    
    if [[ $failed_suites -eq 0 ]]; then
        log_with_timestamp "🎉 ALL TEST SUITES PASSED!"
        return 0
    else
        log_with_timestamp "💥 Some test suites failed"
        return 1
    fi
}

run_direct_tests() {
    local test_file="${1:-}"
    if [[ -n "$test_file" ]]; then
        log_with_timestamp "🧪 Running specific test file: $test_file"
    else
        log_with_timestamp "🧪 Running all integration tests directly against existing Docker containers..."
    fi
    
    # Check if Dokku container is accessible
    DOKKU_CONTAINER="${DOKKU_CONTAINER:-dokku-local}"
    if ! docker exec "$DOKKU_CONTAINER" echo "Container accessible" >/dev/null 2>&1; then
        log_with_timestamp "❌ Dokku container not accessible: $DOKKU_CONTAINER"
        log_with_timestamp "   Start containers first: docker-compose -f tests/docker/docker-compose.yml up -d"
        exit 1
    fi
    
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
                echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            "SUCCESS")
                echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            "WARNING")
                echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
                ;;
            "ERROR")
                echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
                ;;
        esac
    }
    
    # Test Docker connection  
    log "INFO" "Testing connection to Dokku container..."
    if ! docker exec "$DOKKU_CONTAINER" echo "Container accessible" >/dev/null 2>&1; then
        log "ERROR" "Cannot connect to Dokku container: $DOKKU_CONTAINER"
        exit 1
    fi
    log "SUCCESS" "Connection to Dokku container established"
    
    # Generate and run test script inside container
    log "INFO" "Generating and executing comprehensive test suite..."
    
    # All test files are available via Docker volume mount at /tmp/dokku-dns
    
    log "INFO" "Report assertion functions available via Docker volume at /tmp/dokku-dns/tests/integration/"
    
    log "INFO" "Installing DNS plugin in container..."
    # Copy plugin to proper location and install it using Dokku's plugin installer
    docker exec "$DOKKU_CONTAINER" bash -c "cp -r /tmp/dokku-dns /var/lib/dokku/plugins/available/dns"
    
    # Enable the plugin 
    if ! docker exec "$DOKKU_CONTAINER" bash -c "dokku plugin:enable dns"; then
        log "WARNING" "Failed to enable plugin via dokku command, trying manual approach"
        # Manual enable as fallback
        docker exec "$DOKKU_CONTAINER" bash -c "ln -sf /var/lib/dokku/plugins/available/dns /var/lib/dokku/plugins/enabled/dns"
    fi
    
    # Run the install script after the plugin is enabled
    if ! docker exec "$DOKKU_CONTAINER" bash -c "cd /var/lib/dokku/plugins/available/dns && ./install"; then
        log "ERROR" "Failed to run DNS plugin install script"
        return 1
    fi
    
    # Initialize cron for DNS plugin testing
    log "INFO" "Installing and configuring cron service..."
    if ! docker exec "$DOKKU_CONTAINER" bash -c "/usr/local/bin/init-cron.sh"; then
        log "WARNING" "Failed to initialize cron service, DNS cron functionality may not work"
    fi
    
    # Fix permissions after installation
    log "INFO" "Fixing DNS plugin data directory permissions..."
    docker exec "$DOKKU_CONTAINER" bash -c "mkdir -p /var/lib/dokku/services/dns && chown -R dokku:dokku /var/lib/dokku/services/dns 2>/dev/null || true"
    
    # Verify plugin is properly installed and available
    log "INFO" "Verifying DNS plugin installation..."
    local retry_count=0
    local max_retries=10
    while [[ $retry_count -lt $max_retries ]]; do
        if docker exec "$DOKKU_CONTAINER" bash -c "dokku help | grep -q dns" 2>/dev/null; then
            log "SUCCESS" "DNS plugin is available and working"
            break
        else
            retry_count=$((retry_count + 1))
            log "INFO" "Plugin not yet available, retrying... ($retry_count/$max_retries)"
            sleep 2
        fi
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        log "ERROR" "DNS plugin installation verification failed after $max_retries attempts"
        log "INFO" "Debugging plugin installation..."
        docker exec "$DOKKU_CONTAINER" bash -c "ls -la /var/lib/dokku/plugins/available/ | grep dns || echo 'DNS plugin not found in available plugins'"
        docker exec "$DOKKU_CONTAINER" bash -c "ls -la /var/lib/dokku/plugins/enabled/ | grep dns || echo 'DNS plugin not found in enabled plugins'"
        docker exec "$DOKKU_CONTAINER" bash -c "ls -la /var/lib/dokku/services/ | grep dns || echo 'DNS data directory not found'"
        return 1
    fi
    
    log "SUCCESS" "DNS plugin installed and verified successfully"
    
    
    if [[ -n "$test_file" ]]; then
        log "INFO" "Running specific test file from volume: $test_file"
        # Check if test file exists in volume (we'll let Docker handle the actual execution)
        
        # Check if it's a BATS test file
        if [[ "$test_file" == *.bats ]]; then
            log "INFO" "Running BATS integration test: $test_file"
            if docker exec "$DOKKU_CONTAINER" bash -c "cd /tmp/dokku-dns/tests/integration && bats $test_file"; then
                log "SUCCESS" "BATS integration test completed successfully: $test_file"
                return 0
            else
                log "ERROR" "BATS integration test failed: $test_file"
                return 1
            fi
        else
            # Regular bash script - run directly from volume
            if docker exec "$DOKKU_CONTAINER" bash -c "cd /tmp/dokku-dns && chmod +x tests/integration/$test_file && tests/integration/$test_file"; then
                log "SUCCESS" "Specific test file completed successfully!"
                log "INFO" "DNS plugin functionality verified for: $test_file"
                return 0
            else
                log "ERROR" "Test file failed: $test_file. Check the output above for details."
                return 1
            fi
        fi
    else
        log "INFO" "Running comprehensive integration test script from volume..."
        # Use the main comprehensive integration test script directly from volume
        if docker exec "$DOKKU_CONTAINER" bash -c "cd /tmp/dokku-dns && cp scripts/test-integration.sh /tmp/test-integration.sh && chmod +x /tmp/test-integration.sh && /tmp/test-integration.sh"; then
            main_tests_passed=true
        else
            log "ERROR" "Main integration tests failed"
            main_tests_passed=false
        fi
        
        # Also run BATS integration tests if available
        local bats_tests_passed=true
        if docker exec "$DOKKU_CONTAINER" bash -c "which bats && ls /tmp/dokku-dns/tests/integration/*.bats" >/dev/null 2>&1; then
            log "INFO" "Running BATS integration tests..."
            if docker exec "$DOKKU_CONTAINER" bash -c "cd /tmp/dokku-dns/tests/integration && bats *.bats"; then
                log "SUCCESS" "BATS integration tests completed successfully!"
            else
                log "ERROR" "BATS integration tests failed"
                bats_tests_passed=false
            fi
        else
            log "INFO" "BATS integration tests not available (BATS not installed or test files not found)"
        fi
        
        # Overall result
        if [[ "$main_tests_passed" == "true" && "$bats_tests_passed" == "true" ]]; then
            log "SUCCESS" "All integration tests completed successfully!"
            log "INFO" "DNS plugin functionality verified with comprehensive test suite"
            return 0
        else
            log "ERROR" "Some integration tests failed. Check the output above for details."
            return 1
        fi
    fi
}

run_orchestrated_tests() {
    local build_flag="$1"
    local logs_flag="$2"
    local compose_file="tests/docker/docker-compose.yml"
    
    log_with_timestamp "🚀 Starting Docker-based Dokku DNS plugin tests..."
    log_with_timestamp ""
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        log_with_timestamp "❌ Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if .env file exists and load it
    if [[ -f ".env" ]]; then
        log_with_timestamp "📄 Loading environment variables from .env file..."
        set -a
        source .env
        set +a
    elif [[ -f "../.env" ]]; then
        log_with_timestamp "📄 Loading environment variables from ../.env file..."
        set -a
        source ../.env
        set +a
    fi
    
    # Clean up any existing containers
    log_with_timestamp "🧹 Cleaning up existing containers..."
    docker-compose -f "$compose_file" down -v 2>/dev/null || true
    
    # In CI, give containers more time to stop cleanly
    if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        log_with_timestamp "⏱️  Waiting for clean container shutdown in CI..."
        sleep 3
    fi
    
    # Start the containers (build step now separate in CI)
    local start_message="🚀 Starting containers and running tests..."
    if [[ "$build_flag" == "--build" ]]; then
        start_message="🏗️  Building and starting containers..."
    fi
    log_with_timestamp "$start_message"
    
    # Add CI-specific resource handling
    if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        log_with_timestamp "🔍 CI environment detected - using CI optimizations"
    fi
    
    # Build the docker-compose command properly
    local compose_cmd="docker-compose -f $compose_file up"
    if [[ -n "$build_flag" ]]; then
        compose_cmd="$compose_cmd $build_flag"
    fi
    compose_cmd="$compose_cmd --abort-on-container-exit"
    
    # Run docker-compose with logging
    set +e  # Don't exit on error so we can capture exit code
    if eval "$compose_cmd" 2>&1 | tee -a "$LOG_FILE"; then
        local docker_exit_code=0
    else
        local docker_exit_code=$?
    fi
    set -e
    
    log_with_timestamp ""
    if [[ $docker_exit_code -eq 0 ]]; then
        log_with_timestamp "✅ Tests completed successfully!"
        
        if [[ "$logs_flag" == "true" ]]; then
            log_with_timestamp ""
            log_with_timestamp "📋 Container logs:"
            log_with_timestamp "===================="
            docker-compose -f "$compose_file" logs | tee -a "$LOG_FILE"
        fi
    else
        log_with_timestamp "❌ Tests failed!"
        
        log_with_timestamp ""
        log_with_timestamp "📋 Container logs for debugging:"
        log_with_timestamp "================================"
        docker-compose -f "$compose_file" logs | tee -a "$LOG_FILE"
        
        # In CI environments, show additional debugging info
        if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
            log_with_timestamp ""
            log_with_timestamp "🔍 Container status for CI debugging:"
            log_with_timestamp "===================================="
            docker-compose -f "$compose_file" ps -a 2>&1 | tee -a "$LOG_FILE" || true
            
            log_with_timestamp ""
            log_with_timestamp "🐳 Docker system info:"
            log_with_timestamp "====================="
            docker system df 2>&1 | tee -a "$LOG_FILE" || true
        fi
    fi
    
    # Clean up
    log_with_timestamp ""
    log_with_timestamp "🧹 Cleaning up containers..."
    docker-compose -f "$compose_file" down -v 2>/dev/null || true
    
    if [[ $docker_exit_code -eq 0 ]]; then
        log_with_timestamp ""
        log_with_timestamp "🎉 Docker-based testing completed!"
        log_with_timestamp "   Your DNS plugin has been verified!"
        return 0
    else
        return $docker_exit_code
    fi
}

main() {
    local build_flag=""
    local logs_flag=""
    local direct_mode=false
    local test_file=""
    local summary_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build)
                build_flag="--build"
                shift
                ;;
            --logs)
                logs_flag="true"
                shift
                ;;
            --direct)
                direct_mode=true
                shift
                ;;
            --list)
                list_test_suites
                exit 0
                ;;
            --summary)
                summary_mode=true
                direct_mode=true  # Summary mode requires direct mode
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            -*)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
            *)
                # This is a test file argument
                test_file="$1"
                shift
                ;;
        esac
    done
    
    # Initialize logging
    log_with_timestamp "🚀 Starting Docker tests with logging..."
    log_with_timestamp "📝 Log file: $LOG_FILE"
    log_with_timestamp "⏰ Started at: $(date)"
    log_with_timestamp ""
    
    # Run tests based on mode
    set +e  # Don't exit on error so we can capture exit code
    if [[ "$direct_mode" == "true" ]]; then
        if [[ "$summary_mode" == "true" ]]; then
            run_test_suite_summary
            EXIT_CODE=$?
        else
            run_direct_tests "$test_file"
            EXIT_CODE=$?
        fi
    else
        if [[ -n "$test_file" ]]; then
            echo "Error: Test file argument only supported with --direct mode"
            echo "Use --help for usage information"
            exit 1
        fi
        run_orchestrated_tests "$build_flag" "$logs_flag"
        EXIT_CODE=$?
    fi
    set -e
    
    log_with_timestamp ""
    log_with_timestamp "⏰ Completed at: $(date)"
    log_with_timestamp "📊 Exit code: $EXIT_CODE"
    
    # Enhanced result reporting
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_with_timestamp "✅ Docker tests completed successfully!"
        
        # Extract and display test summary if available
        log_with_timestamp ""
        log_with_timestamp "=== 🔍 Quick Test Summary ==="
        if grep -q "📊 Test Results" "$LOG_FILE"; then
            # Extract the formal test summary
            grep -A10 "📊 Test Results" "$LOG_FILE" | grep -E "(Total tests|Passed|Failed|All tests)" | tail -4 | tee -a "$LOG_FILE"
        else
            # Fallback count
            passed_count=$(grep -c "✅" "$LOG_FILE" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" || echo "0")
            log_with_timestamp "✅ Tests passed: $passed_count"
        fi
    else
        log_with_timestamp "❌ Docker tests failed!"
        log_with_timestamp "📝 Full log available at: $LOG_FILE"
        
        # Show failure summary
        log_with_timestamp ""
        log_with_timestamp "=== ⚠️  Failure Summary ==="
        failure_count=$(grep -c "❌" "$LOG_FILE" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" || echo "0")
        if [[ "$failure_count" -gt 0 ]]; then
            log_with_timestamp "❌ Failed tests: $failure_count"
            log_with_timestamp "Recent failures:"
            grep "❌" "$LOG_FILE" | grep -v "no hosted zone" | grep -v "DNS record found" | grep -v "Points to different IP" | tail -5 | tee -a "$LOG_FILE"
        else
            log_with_timestamp "No specific test failures found. Check full log for details."
        fi
        
        log_with_timestamp ""
        log_with_timestamp "💡 Troubleshooting tips:"
        log_with_timestamp "   • View detailed results: scripts/view-test-log.sh --parse"
        log_with_timestamp "   • Follow test execution: scripts/view-test-log.sh --follow"
        log_with_timestamp "   • View last 50 lines: scripts/view-test-log.sh --tail"
    fi
    
    exit "$EXIT_CODE"
}

main "$@"