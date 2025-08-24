#!/usr/bin/env bash
set -euo pipefail

# Docker Integration Test Orchestrator
# Handles Docker Compose setup, cleanup, and test execution

show_help() {
    echo "Usage: $0 [OPTIONS] [TEST_SUITE]"
    echo ""
    echo "TEST_SUITE options:"
    echo "  all             Run all test suites (default)"
    echo "  apps            Run apps subcommand tests"
    echo "  cron            Run cron subcommand tests"
    echo "  zones           Run zones subcommand tests"
    echo "  sync-all        Run sync-all subcommand tests"
    echo "  version         Run version subcommand tests"
    echo ""
    echo "OPTIONS:"
    echo "  --build    Force rebuild of Docker images"
    echo "  --logs     Show container logs after test completion"
    echo "  --direct   Run tests directly (skip Docker Compose orchestration)"
    echo "  --help     Show this help message"
    echo ""
    echo "Environment variables:"
    echo "  AWS_ACCESS_KEY_ID      - AWS access key for Route53 testing"
    echo "  AWS_SECRET_ACCESS_KEY  - AWS secret key for Route53 testing"
    echo "  AWS_DEFAULT_REGION     - AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0 --build                                    # Full Docker Compose testing (all suites)"
    echo "  $0 apps --direct                              # Direct testing (apps suite only)"
    echo "  AWS_ACCESS_KEY_ID=xxx $0 cron --logs          # With AWS credentials (cron suite)"
}

run_direct_tests() {
    local test_suite="$1"
    echo "🧪 Running tests directly against existing Docker containers..."
    
    # Check if Dokku container is accessible
    DOKKU_CONTAINER="${DOKKU_CONTAINER:-dokku-local}"
    if ! docker exec "$DOKKU_CONTAINER" echo "Container accessible" >/dev/null 2>&1; then
        echo "❌ Dokku container not accessible: $DOKKU_CONTAINER"
        echo "   Start containers first: docker-compose -f tests/docker/docker-compose.yml up -d"
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
    
    # Test Docker connection  
    log "INFO" "Testing connection to Dokku container..."
    if ! docker exec "$DOKKU_CONTAINER" echo "Container accessible" >/dev/null 2>&1; then
        log "ERROR" "Cannot connect to Dokku container: $DOKKU_CONTAINER"
        exit 1
    fi
    log "SUCCESS" "Connection to Dokku container established"
    
    # Generate and run test script inside container
    log "INFO" "Generating and executing comprehensive test suite..."
    
    # Copy the assertion functions and integration test script
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    log "INFO" "Copying report assertion functions to container..."
    docker exec -i "$DOKKU_CONTAINER" bash -c "cat > /tmp/report-assertions.sh && chmod +x /tmp/report-assertions.sh" < "$SCRIPT_DIR/report-assertions.sh" || {
        log "WARNING" "Failed to copy report assertions, falling back to basic verification"
    }
    
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
    
    # Run modular test system
    log "INFO" "Running test suite: $test_suite"
    
    # Copy all modular test files to container
    log "INFO" "Copying modular test files to container..."
    docker exec "$DOKKU_CONTAINER" bash -c "mkdir -p /tmp/integration"
    
    # Copy test modules
    local test_files=(
        "common.sh"
        "apps-test.sh" 
        "cron-test.sh"
        "zones-test.sh"
        "sync-all-test.sh"
        "version-test.sh"
        "dns-integration-tests-modular.sh"
    )
    
    for file in "${test_files[@]}"; do
        if [[ -f "$SCRIPT_DIR/$file" ]]; then
            docker exec -i "$DOKKU_CONTAINER" bash -c "cat > /tmp/integration/$file && chmod +x /tmp/integration/$file" < "$SCRIPT_DIR/$file"
        else
            log "WARNING" "Test file not found: $file"
        fi
    done
    
    # Run modular tests
    if docker exec "$DOKKU_CONTAINER" bash -c "cd /tmp/dokku-dns && /tmp/integration/dns-integration-tests-modular.sh $test_suite"; then
        log "SUCCESS" "All modular tests completed successfully!"
        log "INFO" "DNS plugin functionality verified with modular test suite"
        return 0
    else
        log "ERROR" "Modular integration tests failed!"
        return 1
    fi
}

run_orchestrated_tests() {
    local build_flag="$1"
    local logs_flag="$2"
    local test_suite="$3"
    local compose_file="tests/docker/docker-compose.yml"
    
    echo "🚀 Starting Docker-based Dokku DNS plugin tests..."
    echo ""
    
    # Check if Docker is running
    if ! docker info >/dev/null 2>&1; then
        echo "❌ Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    # Check if .env file exists and load it
    if [[ -f ".env" ]]; then
        echo "📄 Loading environment variables from .env file..."
        set -a
        source .env
        set +a
    elif [[ -f "../.env" ]]; then
        echo "📄 Loading environment variables from ../.env file..."
        set -a
        source ../.env
        set +a
    fi
    
    # Clean up any existing containers
    echo "🧹 Cleaning up existing containers..."
    docker-compose -f "$compose_file" down -v 2>/dev/null || true
    
    # In CI, give containers more time to stop cleanly
    if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "⏱️  Waiting for clean container shutdown in CI..."
        sleep 3
    fi
    
    # Start the containers (build step now separate in CI)
    local start_message="🚀 Starting containers and running tests..."
    if [[ "$build_flag" == "--build" ]]; then
        start_message="🏗️  Building and starting containers..."
    fi
    echo "$start_message"
    
    # Add CI-specific resource handling
    if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
        echo "🔍 CI environment detected - using CI optimizations"
    fi
    
    # Build the docker-compose command properly
    local compose_cmd="docker-compose -f $compose_file up"
    if [[ -n "$build_flag" ]]; then
        compose_cmd="$compose_cmd $build_flag"
    fi
    compose_cmd="$compose_cmd --abort-on-container-exit"
    
    if eval "$compose_cmd"; then
        echo ""
        echo "✅ Tests completed successfully!"
        
        if [[ "$logs_flag" == "true" ]]; then
            echo ""
            echo "📋 Container logs:"
            echo "===================="
            docker-compose -f "$compose_file" logs
        fi
        
        # Clean up
        echo ""
        echo "🧹 Cleaning up containers..."
        docker-compose -f "$compose_file" down -v 2>/dev/null || true
        
        echo ""
        echo "🎉 Docker-based testing completed!"
        echo "   Your DNS plugin has been verified!"
        return 0
    else
        echo ""
        echo "❌ Tests failed!"
        
        echo ""
        echo "📋 Container logs for debugging:"
        echo "================================"
        docker-compose -f "$compose_file" logs
        
        # In CI environments, show additional debugging info
        if [[ "${CI:-}" == "true" || "${GITHUB_ACTIONS:-}" == "true" ]]; then
            echo ""
            echo "🔍 Container status for CI debugging:"
            echo "===================================="
            docker-compose -f "$compose_file" ps -a || true
            
            echo ""
            echo "🐳 Docker system info:"
            echo "====================="
            docker system df || true
        fi
        
        # Clean up
        docker-compose -f "$compose_file" down -v 2>/dev/null || true
        return 1
    fi
}

main() {
    local build_flag=""
    local logs_flag=""
    local direct_mode=false
    local test_suite="all"
    
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
            --help|-h)
                show_help
                exit 0
                ;;
            all|apps|cron|zones|sync-all|version|apps-test|cron-test|zones-test|sync-all-test|version-test)
                test_suite="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    if [[ "$direct_mode" == "true" ]]; then
        run_direct_tests "$test_suite"
    else
        run_orchestrated_tests "$build_flag" "$logs_flag" "$test_suite"
    fi
}

main "$@"