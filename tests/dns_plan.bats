#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  mkdir -p "$PLUGIN_DATA_ROOT"
  
  # Mock the AWS provider function for plan tests
  dns_provider_aws_get_hosted_zone_id() {
    local DOMAIN="$1"
    
    # Check for credential failure simulation
    if [[ "${AWS_MOCK_FAIL_CREDENTIALS:-}" == "true" ]]; then
      return 1
    fi
    
    # Mock implementation for testing
    case "$DOMAIN" in
        "example.com"|*.example.com)
            echo "Z1234567890ABC"
            return 0
            ;;
        "test.org"|*.test.org)
            echo "Z0987654321DEF"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
  }
  export -f dns_provider_aws_get_hosted_zone_id
  
  # Mock the AWS get record IP function for plan tests
  dns_provider_aws_get_record_ip() {
    local DOMAIN="$1"
    
    # Check for credential failure simulation
    if [[ "${AWS_MOCK_FAIL_CREDENTIALS:-}" == "true" ]]; then
      return 1
    fi
    
    # Mock existing records for testing
    case "$DOMAIN" in
        "existing.example.com")
            echo "192.168.1.100"  # Existing record with correct IP
            return 0
            ;;
        "outdated.example.com")
            echo "192.168.1.99"   # Existing record with wrong IP
            return 0
            ;;
        "new.example.com")
            return 1  # No existing record
            ;;
        *)
            return 1  # No record by default
            ;;
    esac
  }
  export -f dns_provider_aws_get_record_ip
  
  # Mock get_server_ip to return consistent IP for testing
  get_server_ip() {
    echo "192.168.1.100"
  }
  export -f get_server_ip
}

teardown() {
  cleanup_dns_data
  unset -f dns_provider_aws_get_hosted_zone_id
  unset -f dns_provider_aws_get_record_ip
  unset -f get_server_ip
}

@test "(dns_plan_changes) returns error when app has no DNS domains" {
  create_test_app test-app
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  # Check that output contains the expected lines
  [[ "$output" =~ ADD_COUNT:0 ]]
  [[ "$output" =~ CHANGE_COUNT:0 ]]  
  [[ "$output" =~ NO_CHANGE_COUNT:0 ]]
  [[ "$output" =~ TOTAL_COUNT:0 ]]
  [[ "$output" =~ "ERROR:No DNS-managed domains found for app: test-app" ]]
  
  cleanup_test_app test-app
}

@test "(dns_plan_changes) plans to add new DNS records" {
  create_test_app test-app
  add_test_domains test-app new.example.com
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  [[ "$output" =~ "ADD:new.example.com:192.168.1.100" ]]
  [[ "$output" =~ ADD_COUNT:1 ]]
  [[ "$output" =~ CHANGE_COUNT:0 ]]
  [[ "$output" =~ NO_CHANGE_COUNT:0 ]]
  [[ "$output" =~ TOTAL_COUNT:1 ]]
  
  cleanup_test_app test-app
}

@test "(dns_plan_changes) plans to change existing DNS records with wrong IP" {
  create_test_app test-app
  add_test_domains test-app outdated.example.com
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  [[ "$output" =~ "CHANGE:outdated.example.com:192.168.1.100:192.168.1.99" ]]
  [[ "$output" =~ ADD_COUNT:0 ]]
  [[ "$output" =~ CHANGE_COUNT:1 ]]
  [[ "$output" =~ NO_CHANGE_COUNT:0 ]]
  [[ "$output" =~ TOTAL_COUNT:1 ]]
  
  cleanup_test_app test-app
}

@test "(dns_plan_changes) shows no changes needed when DNS records are correct" {
  create_test_app test-app
  add_test_domains test-app existing.example.com
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  [[ "$output" =~ "NO_CHANGE:existing.example.com:192.168.1.100" ]]
  [[ "$output" =~ ADD_COUNT:0 ]]
  [[ "$output" =~ CHANGE_COUNT:0 ]]
  [[ "$output" =~ NO_CHANGE_COUNT:1 ]]
  [[ "$output" =~ TOTAL_COUNT:1 ]]
  
  cleanup_test_app test-app
}

@test "(dns_plan_changes) handles mixed scenarios" {
  create_test_app test-app
  add_test_domains test-app existing.example.com outdated.example.com new.example.com
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  [[ "$output" =~ "NO_CHANGE:existing.example.com:192.168.1.100" ]]
  [[ "$output" =~ "CHANGE:outdated.example.com:192.168.1.100:192.168.1.99" ]]
  [[ "$output" =~ "ADD:new.example.com:192.168.1.100" ]]
  [[ "$output" =~ ADD_COUNT:1 ]]
  [[ "$output" =~ CHANGE_COUNT:1 ]]
  [[ "$output" =~ NO_CHANGE_COUNT:1 ]]
  [[ "$output" =~ TOTAL_COUNT:3 ]]
  
  cleanup_test_app test-app
}

@test "(dns_plan_changes) handles domains without hosted zones" {
  create_test_app test-app
  add_test_domains test-app invalid-domain.unknown
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  [[ "$output" =~ "ERROR_DOMAIN:invalid-domain.unknown:No hosted zone found" ]]
  [[ "$output" =~ ADD_COUNT:0 ]]
  [[ "$output" =~ CHANGE_COUNT:0 ]]
  [[ "$output" =~ NO_CHANGE_COUNT:0 ]]
  [[ "$output" =~ TOTAL_COUNT:0 ]]
  
  cleanup_test_app test-app
}

@test "(dns_plan_changes) handles AWS credential failures" {
  create_test_app test-app
  add_test_domains test-app example.com
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  # Set environment variable to simulate credential failure
  export AWS_MOCK_FAIL_CREDENTIALS=true
  
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app"
  assert_success
  
  [[ "$output" =~ "ERROR_DOMAIN:example.com:No hosted zone found" ]]
  
  # Clean up environment variable
  unset AWS_MOCK_FAIL_CREDENTIALS
  cleanup_test_app test-app
}

@test "(dns_plan_changes) works with different providers" {
  create_test_app test-app
  add_test_domains test-app new.example.com
  
  # Enable DNS management for the app
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" test-app >/dev/null 2>&1
  
  # Test with explicit AWS provider
  run bash -c "source \"$PLUGIN_ROOT/functions\" && dns_plan_changes test-app aws"
  assert_success
  
  [[ "$output" =~ "ADD:new.example.com:192.168.1.100" ]]
  
  cleanup_test_app test-app
}