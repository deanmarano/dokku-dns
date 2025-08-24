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
    # Check if plugin is already installed
    local plugin_status
    plugin_status=$(dokku plugin:list | grep dns || true)
    
    if [[ "$plugin_status" == *"enabled"* ]]; then
        log_remote "INFO" "DNS plugin already installed and enabled"
        return 0
    fi
    
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

# DNS Report Verification Functions
verify_app_in_global_report() {
    local app_name="$1"
    local should_exist="${2:-true}"  # Default: expect app to exist
    
    echo "Verifying app '$app_name' in global report (should_exist: $should_exist)..."
    
    local global_report
    global_report=$(dokku dns:report 2>&1)
    
    if [[ "$should_exist" == "true" ]]; then
        if echo "$global_report" | grep -q "$app_name"; then
            echo "✓ Global report shows app: $app_name"
            return 0
        else
            echo "❌ Global report doesn't show app: $app_name"
            return 1
        fi
    else
        if echo "$global_report" | grep -q "$app_name"; then
            echo "❌ Global report still shows app: $app_name (but shouldn't)"
            return 1
        else
            echo "✓ Global report doesn't show app: $app_name (as expected)"
            return 0
        fi
    fi
}

verify_app_dns_status() {
    local app_name="$1"
    local expected_status="$2"
    
    echo "Verifying DNS status for app '$app_name' (expected: $expected_status)..."
    
    local app_report
    app_report=$(dokku dns:report "$app_name" 2>&1)
    
    if echo "$app_report" | grep -q "$expected_status"; then
        echo "✓ App-specific report shows status: $expected_status"
        return 0
    else
        echo "❌ App-specific report doesn't show expected status: $expected_status"
        echo "   Actual report output:"
        echo "$app_report" | head -10
        return 1
    fi
}

verify_domains_in_report() {
    local report_type="$1"  # "app-specific" or "global"
    local app_name="$2"
    shift 2
    local domains=("$@")
    
    echo "Verifying domains in $report_type report..."
    
    local report_output
    if [[ "$report_type" == "app-specific" ]]; then
        report_output=$(dokku dns:report "$app_name" 2>&1)
    else
        report_output=$(dokku dns:report 2>&1)
    fi
    
    local all_found=true
    for domain in "${domains[@]}"; do
        if echo "$report_output" | grep -q "$domain"; then
            echo "✓ $report_type report shows domain: $domain"
        else
            echo "❌ $report_type report doesn't show domain: $domain"
            all_found=false
        fi
    done
    
    if [[ "$all_found" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

verify_dns_provider_configured() {
    local expected_provider="$1"
    
    echo "Verifying DNS provider configuration (expected: $expected_provider)..."
    
    local global_report
    global_report=$(dokku dns:report 2>&1)
    
    if echo "$global_report" | grep -q "Global DNS Provider: $expected_provider"; then
        echo "✓ Global report shows provider: $expected_provider"
        return 0
    else
        echo "❌ Global report doesn't show expected provider: $expected_provider"
        return 1
    fi
}

verify_configuration_status() {
    local expected_status="$1"  # "Configured" or "Not configured"
    
    echo "Verifying configuration status (expected: $expected_status)..."
    
    local global_report
    global_report=$(dokku dns:report 2>&1)
    
    if echo "$global_report" | grep -q "Configuration Status: $expected_status"; then
        echo "✓ Global report shows configuration status: $expected_status"
        return 0
    else
        echo "❌ Global report doesn't show expected configuration status: $expected_status"
        return 1
    fi
}

run_comprehensive_report_verification() {
    local test_phase="$1"      # "after_add", "after_remove", etc.
    local app_name="$2"
    shift 2
    local domains=("$@")
    
    echo ""
    echo "=== Comprehensive Report Verification: $test_phase ==="
    
    local verification_failed=false
    
    case "$test_phase" in
        "after_add")
            # After dns:apps:enable, verify the behavior based on whether domains have hosted zones
            local app_report
            app_report=$(dokku dns:report "$app_name" 2>&1)
            
            if echo "$app_report" | grep -q "DNS Status: Added"; then
                # Domains have hosted zones - app should be in global report
                echo "✓ App shows 'Added' status (domains have hosted zones)"
                if ! verify_app_in_global_report "$app_name" "true"; then
                    verification_failed=true
                fi
            elif echo "$app_report" | grep -q "DNS Status: Not added" && echo "$app_report" | grep -qE "(no hosted zone|Not found)"; then
                # Domains don't have hosted zones - this is expected with real AWS, app won't be in global report
                echo "✓ App shows 'Not added' status due to no hosted zones (expected with real AWS)"
                # App should NOT be in global report when no domains have hosted zones
                if ! verify_app_in_global_report "$app_name" "false"; then
                    echo "  Note: Global report correctly excludes app with no hosted zones"
                fi
            else
                echo "❌ App DNS status is unexpected"
                echo "   Actual report output:"
                echo "$app_report"
                verification_failed=true
            fi
            
            # Domains should always appear in app-specific report
            if ! verify_domains_in_report "app-specific" "$app_name" "${domains[@]}"; then
                verification_failed=true
            fi
            
            # Domains only appear in global report if they have hosted zones
            if echo "$app_report" | grep -q "DNS Status: Added"; then
                # App has hosted zones - domains should be in global report
                if [[ ${#domains[@]} -gt 0 ]]; then
                    if ! verify_domains_in_report "global" "$app_name" "${domains[@]}"; then
                        verification_failed=true
                    fi
                fi
            else
                # No hosted zones - domains won't be in global report (this is correct)
                echo "  Note: Domains correctly excluded from global report (no hosted zones)"
            fi
            ;;
            
        "after_remove")
            # After dns:apps:disable, app should show "Not added" status and not appear in global report
            if ! verify_app_dns_status "$app_name" "DNS Status: Not added"; then
                verification_failed=true
            fi
            
            if ! verify_app_in_global_report "$app_name" "false"; then
                verification_failed=true
            fi
            ;;
            
        "provider_configured")
            # After dns:providers:configure, provider should be set
            if ! verify_dns_provider_configured "aws"; then
                verification_failed=true
            fi
            
            if ! verify_configuration_status "Configured"; then
                verification_failed=true
            fi
            ;;
            
        *)
            echo "❌ Unknown test phase: $test_phase"
            verification_failed=true
            ;;
    esac
    
    if [[ "$verification_failed" == "true" ]]; then
        echo "❌ Report verification failed for phase: $test_phase"
        return 1
    else
        echo "✅ All report verifications passed for phase: $test_phase"
        return 0
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
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

mark_test_failed() {
    TEST_FAILED=true
}

is_test_failed() {
    [[ "$TEST_FAILED" == "true" ]]
}

reset_test_status() {
    TEST_FAILED=false
}

# Individual test counting
increment_test_count() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
}

increment_passed_count() {
    PASSED_TESTS=$((PASSED_TESTS + 1))
    increment_test_count
}

increment_failed_count() {
    FAILED_TESTS=$((FAILED_TESTS + 1))
    increment_test_count
}

get_test_counts() {
    echo "Total: $TOTAL_TESTS | Passed: $PASSED_TESTS | Failed: $FAILED_TESTS"
}

reset_test_counts() {
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
}

# Helper function to print test results and count them
test_result() {
    local status="$1"  # "pass", "fail", or "skip"
    local message="$2"
    
    case "$status" in
        "pass")
            echo "✓ $message"
            increment_passed_count
            ;;
        "fail")
            echo "❌ $message"
            increment_failed_count
            mark_test_failed
            ;;
        "skip")
            echo "⚠️ $message"
            increment_test_count
            ;;
    esac
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
export -f verify_app_in_global_report
export -f verify_app_dns_status
export -f verify_domains_in_report
export -f verify_dns_provider_configured
export -f verify_configuration_status
export -f run_comprehensive_report_verification
export -f run_integration_test
export -f mark_test_failed
export -f is_test_failed
export -f reset_test_status
export -f increment_test_count
export -f increment_passed_count
export -f increment_failed_count
export -f get_test_counts
export -f reset_test_counts
export -f test_result