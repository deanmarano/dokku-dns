#!/usr/bin/env bash

# DNS Report Assertion Functions
# Reusable functions for verifying DNS plugin report content

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
            # After dns:apps:enable, app should show up in both reports with "Added" status
            if ! verify_app_dns_status "$app_name" "DNS Status: Added"; then
                verification_failed=true
            fi
            
            if ! verify_app_in_global_report "$app_name" "true"; then
                verification_failed=true
            fi
            
            if ! verify_domains_in_report "app-specific" "$app_name" "${domains[@]}"; then
                verification_failed=true
            fi
            
            if [[ ${#domains[@]} -gt 0 ]]; then
                if ! verify_domains_in_report "global" "$app_name" "${domains[@]}"; then
                    verification_failed=true
                fi
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