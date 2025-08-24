#!/usr/bin/env bash
# DNS Plugin Integration Test Common Utilities
# Shared functions and setup used across all test suites

set -euo pipefail

# Common logging function
log_remote() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1: $2"
}

# Install DNS plugin in container
install_dns_plugin() {
    log_remote "INFO" "Installing DNS plugin..."
    rm -rf /var/lib/dokku/plugins/available/dns
    cp -r /tmp/dokku-dns /var/lib/dokku/plugins/available/dns
    chown -R dokku:dokku /var/lib/dokku/plugins/available/dns
    dokku plugin:enable dns
    /var/lib/dokku/plugins/available/dns/install || echo "Install script completed with warnings"
    
    # Verify installation
    dokku plugin:list | grep dns || {
        echo "ERROR: DNS plugin not found in plugin list"
        exit 1
    }
    echo "✓ DNS plugin installed successfully"
}

# Setup AWS credentials if provided
setup_aws_credentials() {
    if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && [[ -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
        log_remote "INFO" "Setting up AWS credentials..."
        mkdir -p ~/.aws
        cat > ~/.aws/credentials << EOF
[default]
aws_access_key_id = ${AWS_ACCESS_KEY_ID}
aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
EOF
        cat > ~/.aws/config << EOF
[default]
region = ${AWS_DEFAULT_REGION:-us-east-1}
output = json
EOF
        echo "AWS credentials configured"
    fi
    
    # Test AWS connectivity
    if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
        echo "✓ AWS CLI is working"
    else
        echo "⚠️ AWS CLI not configured or not working"
    fi
}

# Create test app with domains
create_test_app() {
    local app_name="$1"
    shift
    local domains=("$@")
    
    echo "Setting up test app: $app_name"
    if ! dokku apps:list 2>/dev/null | grep -q "$app_name"; then
        dokku apps:create "$app_name" 2>&1 || echo "Failed to create app, using existing"
    fi
    
    # Add test domains
    for domain in "${domains[@]}"; do
        dokku domains:add "$app_name" "$domain" 2>&1 || echo "Domain add completed"
    done
}

# Clean up test app
cleanup_test_app() {
    local app_name="$1"
    dokku apps:destroy "$app_name" --force 2>&1 || echo "App cleanup completed"
}

# Source report assertion functions if available
load_report_assertions() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$script_dir/report-assertions.sh" ]]; then
        source "$script_dir/report-assertions.sh"
    elif [[ -f "/tmp/report-assertions.sh" ]]; then
        source "/tmp/report-assertions.sh"
    else
        echo "⚠️ Report assertion functions not found, using basic verification"
    fi
}

# Generic test runner for simple command tests
run_integration_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_pattern="$3"
    local description="$4"
    
    echo ""
    echo "Testing: $test_name - $description"
    echo "Command: $test_command"
    
    if eval "$test_command" 2>&1 | grep -q "$expected_pattern"; then
        echo "✓ $description"
        return 0
    else
        echo "❌ $description failed"
        return 1
    fi
}

# Test result tracking
TEST_FAILED=false

mark_test_failed() {
    TEST_FAILED=true
}

is_test_failed() {
    [[ "$TEST_FAILED" == "true" ]]
}

reset_test_status() {
    TEST_FAILED=false
}

# Common test app names (only set if not already defined)
if [[ -z "${MAIN_TEST_APP:-}" ]]; then
    readonly MAIN_TEST_APP="my-test-app"
    readonly ZONES_TEST_APP="zones-test-app"
    readonly CRON_TEST_APP="cron-test-app"
    
    # Common test domains
    readonly MAIN_DOMAINS=("test.example.com" "api.test.example.com")
    readonly ZONES_DOMAINS=("app.example.com" "api.example.com")
fi

# Export functions for use in test modules
export -f log_remote
export -f install_dns_plugin
export -f setup_aws_credentials
export -f create_test_app
export -f cleanup_test_app
export -f load_report_assertions
export -f run_integration_test
export -f mark_test_failed
export -f is_test_failed
export -f reset_test_status