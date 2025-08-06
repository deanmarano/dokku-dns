#!/usr/bin/env bash
set -euo pipefail

# Docker Integration Test Orchestrator
# Handles Docker Compose setup, cleanup, and test execution

show_help() {
    echo "Usage: $0 [--build] [--logs] [--direct]"
    echo ""
    echo "Options:"
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
    echo "  $0 --build                                    # Full Docker Compose testing"
    echo "  AWS_ACCESS_KEY_ID=xxx $0 --logs               # With AWS credentials"
    echo "  $0 --direct                                   # Direct testing (containers must be running)"
}

run_direct_tests() {
    echo "🧪 Running tests directly against existing Docker containers..."
    
    # Check if Dokku container is accessible
    DOKKU_CONTAINER="${DOKKU_CONTAINER:-dokku-local}"
    if ! docker exec "$DOKKU_CONTAINER" echo "Container accessible" >/dev/null 2>&1; then
        echo "❌ Dokku container not accessible: $DOKKU_CONTAINER"
        echo "   Start containers first: docker-compose -f docker-compose.local.yml up -d"
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
    # Install the plugin first
    if ! docker exec "$DOKKU_CONTAINER" bash -c "cd /tmp/dokku-dns && ./install"; then
        log "ERROR" "Failed to install DNS plugin"
        return 1
    fi
    
    # Fix permissions after installation
    log "INFO" "Fixing DNS plugin data directory permissions..."
    docker exec "$DOKKU_CONTAINER" bash -c "chown -R dokku:dokku /var/lib/dokku/data/dns 2>/dev/null || true"
    
    log "SUCCESS" "DNS plugin installed successfully"
    
    log "INFO" "Copying and executing integration test script..."
    # Use the new comprehensive integration test script
    local INTEGRATION_SCRIPT="$SCRIPT_DIR/../../test-integration.sh"
    if [[ ! -f "$INTEGRATION_SCRIPT" ]]; then
        log "ERROR" "Integration test script not found: $INTEGRATION_SCRIPT"
        return 1
    fi
    
    if docker exec -i "$DOKKU_CONTAINER" bash -c "cat > /tmp/test-integration.sh && chmod +x /tmp/test-integration.sh && cd /tmp/dokku-dns && /tmp/test-integration.sh" < "$INTEGRATION_SCRIPT"; then
        log "SUCCESS" "All tests completed successfully!"
        log "INFO" "DNS plugin functionality verified with comprehensive test suite"
        return 0
    else
        log "ERROR" "Tests failed. Check the output above for details."
        return 1
    fi
}

run_orchestrated_tests() {
    local build_flag="$1"
    local logs_flag="$2"
    local compose_file="docker-compose.local.yml"
    
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
    
    # Build and start the containers
    echo "🏗️  Building and starting containers..."
    if docker-compose -f "$compose_file" up $build_flag --abort-on-container-exit; then
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
        
        # Clean up
        docker-compose -f "$compose_file" down -v 2>/dev/null || true
        return 1
    fi
}

main() {
    local build_flag=""
    local logs_flag=""
    local direct_mode=false
    
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
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    if [[ "$direct_mode" == "true" ]]; then
        run_direct_tests
    else
        run_orchestrated_tests "$build_flag" "$logs_flag"
    fi
}

main "$@"