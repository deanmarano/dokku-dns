#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  mkdir -p "$PLUGIN_DATA_ROOT"
  
  # Create provider file
  echo "aws" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  # Set up PATH to use our mock AWS CLI
  export PATH="$PLUGIN_ROOT/tests/bin:$PATH"
  
  # Mock the AWS provider functions for end-to-end workflow testing
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
  
  # Mock the AWS get record IP function with state tracking
  dns_provider_aws_get_record_ip() {
    local DOMAIN="$1"
    local state_file="$TEST_TMP_DIR/dns_state_$DOMAIN"
    
    # Check for credential failure simulation
    if [[ "${AWS_MOCK_FAIL_CREDENTIALS:-}" == "true" ]]; then
      return 1
    fi
    
    # Check if record was "created" or "updated" by previous sync
    if [[ -f "$state_file" ]]; then
      cat "$state_file"
      return 0
    fi
    
    # Get the server IP for consistent mocking
    local SERVER_IP
    SERVER_IP=$(bash -c 'source "'$PLUGIN_ROOT'/functions" && get_server_ip')
    
    # Initial state - some records exist, some don't
    case "$DOMAIN" in
        "existing.example.com")
            echo "$SERVER_IP"     # Already correct
            return 0
            ;;
        "outdated.example.com")
            echo "192.168.1.50"   # Wrong IP, needs update
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
  
  # Mock get_server_ip to prevent network calls during testing
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
  rm -f "$TEST_TMP_DIR"/dns_state_* 2>/dev/null || true
  
  # Restore original AWS mock if it existed
  if [[ -f "$PLUGIN_ROOT/tests/bin/aws.backup" ]]; then
    mv "$PLUGIN_ROOT/tests/bin/aws.backup" "$PLUGIN_ROOT/tests/bin/aws"
  fi
  
  # Restore original dig mock if it existed
  if [[ -f "$PLUGIN_ROOT/tests/bin/dig.backup" ]]; then
    mv "$PLUGIN_ROOT/tests/bin/dig.backup" "$PLUGIN_ROOT/tests/bin/dig"
  fi
}

@test "(plan/apply workflow) complete end-to-end workflow with mixed scenarios" {
  create_test_app workflow-app
  add_test_domains workflow-app existing.example.com outdated.example.com new.example.com
  
  # Get the server IP for consistent testing (mocked in setup)
  local SERVER_IP="192.168.1.100"
  
  # Set up provider credentials mock to make provider "ready"
  mkdir -p "$PLUGIN_DATA_ROOT/credentials"
  echo "test" > "$PLUGIN_DATA_ROOT/credentials/AWS_ACCESS_KEY_ID"
  
  # Step 0: Enable zones first
  run dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" example.com
  assert_success
  
  # Step 1: Enable DNS management for the app
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" workflow-app
  assert_success
  
  # Re-export the mock functions after they might have been overridden
  export -f dns_provider_aws_get_hosted_zone_id
  export -f dns_provider_aws_get_record_ip
  
  # Step 2: Check initial plan using dns:report
  run dokku "$PLUGIN_COMMAND_PREFIX:report" workflow-app
  assert_success
  
  # Should show planned changes
  assert_output_contains "Planned Changes:"
  assert_output_contains "+ new.example.com → "
  assert_output_contains "~ outdated.example.com → "
  assert_output_contains "[was: 192.168.1.50]"
  assert_output_contains "Plan: 1 to add, 1 to change, 0 to destroy"
  assert_output_contains "Run 'dokku dns:apps:sync workflow-app' to apply changes"
  
  # Should not show existing.example.com in changes (already correct)
  [[ "$output" != *"+ existing.example.com"* ]]
  [[ "$output" != *"~ existing.example.com"* ]]
  
  # Step 3: Apply changes using dns:apps:sync
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" workflow-app
  assert_success
  
  # Should show the plan first, then apply it
  assert_output_contains "=====> DNS Sync for app: workflow-app"
  assert_output_contains "-----> Target IP: "
  assert_output_contains "-----> Will "
  assert_output_contains " new.example.com → "
  assert_output_contains " outdated.example.com → "
  assert_output_contains " (A record)"
  assert_output_contains "=====> Applying changes..."
  assert_output_contains "✅ "
  assert_output_contains "=====> Sync complete! Resources:"
  
  # Simulate the DNS records being updated by storing new state
  echo "$SERVER_IP" > "$TEST_TMP_DIR/dns_state_new.example.com"
  echo "$SERVER_IP" > "$TEST_TMP_DIR/dns_state_outdated.example.com"
  
  # Step 4: Check plan again after sync - should show no changes needed
  run dokku "$PLUGIN_COMMAND_PREFIX:report" workflow-app
  assert_success
  
  assert_output_contains "Planned Changes:"
  assert_output_contains "No changes needed - all DNS records are already correct"
  
  # Should not show any + or ~ changes
  [[ "$output" != *"+ "*" → "*" (A record)"* ]]
  [[ "$output" != *"~ "*" → "*" (A record)"* ]]
  
  # Step 5: Run sync again - should show no changes needed
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" workflow-app
  assert_success
  
  assert_output_contains "=====> DNS Sync for app: workflow-app"
  assert_output_contains "-----> Already correct: "
  assert_output_contains " example.com → "
  assert_output_contains " (A record)"
  assert_output_contains "=====> No changes needed - all DNS records are already correct"
  
  # Should not contain "Applying changes" section
  [[ "$output" != *"=====> Applying changes..."* ]]
  
  cleanup_test_app workflow-app
}

@test "(plan/apply workflow) workflow with global report" {
  create_test_app global-app1
  create_test_app global-app2
  add_test_domains global-app1 app1.example.com
  add_test_domains global-app2 app2.example.com new-domain.example.com
  
  # Set up provider credentials mock
  mkdir -p "$PLUGIN_DATA_ROOT/credentials"
  echo "test" > "$PLUGIN_DATA_ROOT/credentials/AWS_ACCESS_KEY_ID"
  
  # Enable zones first
  dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" example.com >/dev/null 2>&1
  
  # Enable DNS for both apps
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" global-app1 >/dev/null 2>&1
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" global-app2 >/dev/null 2>&1
  
  # Check global report shows all apps
  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  
  assert_output_contains "DNS Global Report - All Apps"
  assert_output_contains "global-app1"
  assert_output_contains "app1.example.com"
  assert_output_contains "global-app2"
  assert_output_contains "app2.example.com"
  assert_output_contains "new-domain.example.com"
  
  # Should show summary of domain status
  assert_output_contains "Summary:"
  assert_output_contains "Total domains:"
  
  cleanup_test_app global-app1
  cleanup_test_app global-app2
}

@test "(plan/apply workflow) workflow with error handling" {
  create_test_app error-app
  add_test_domains error-app good.example.com bad.invalid
  
  # Get the server IP for consistent testing (mocked in setup)
  local SERVER_IP="192.168.1.100"
  
  # Set up provider credentials mock
  mkdir -p "$PLUGIN_DATA_ROOT/credentials"
  echo "test" > "$PLUGIN_DATA_ROOT/credentials/AWS_ACCESS_KEY_ID"
  
  # Enable zones first
  dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" example.com >/dev/null 2>&1
  
  # Enable DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" error-app >/dev/null 2>&1
  
  # Check plan shows error for domain without hosted zone
  run dokku "$PLUGIN_COMMAND_PREFIX:report" error-app
  assert_success
  
  assert_output_contains "Planned Changes:"
  assert_output_contains "+ good.example.com → "
  assert_output_contains " (A record)"
  assert_output_contains "! bad.invalid:No hosted zone found"
  assert_output_contains "Plan: 1 to add, 0 to change, 0 to destroy"
  
  # Apply changes - should handle errors gracefully
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" error-app
  assert_success
  
  assert_output_contains "=====> DNS Sync for app: error-app"
  assert_output_contains "-----> Will create: good.example.com → 192.168.1.100 (A record)"
  assert_output_contains "=====> Applying changes..."
  assert_output_contains "✅ Created: good.example.com → 192.168.1.100 (A record)"
  assert_output_contains "❌ Error: No hosted zone found for bad.invalid"
  assert_output_contains "=====> Sync complete! Resources: 1 changed, 1 failed"
  
  cleanup_test_app error-app
}

@test "(plan/apply workflow) workflow consistency between report and sync" {
  create_test_app consistent-app
  add_test_domains consistent-app test.example.com
  
  # Enable DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" consistent-app >/dev/null 2>&1
  
  # Get plan from report
  run dokku "$PLUGIN_COMMAND_PREFIX:report" consistent-app
  assert_success
  local report_output="$output"
  
  # Get plan from sync (before applying)
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" consistent-app
  assert_success
  local sync_output="$output"
  
  # Both should show the same domain will be created
  [[ "$report_output" =~ "+ test.example.com → " ]]
  [[ "$sync_output" =~ "-----> Will create: test.example.com → " ]]
  
  # Both should show Plan: 1 to add
  [[ "$report_output" =~ "Plan: 1 to add, 0 to change, 0 to destroy" ]]
  [[ "$sync_output" =~ "✅ Created: test.example.com → " ]]
  [[ "$sync_output" =~ "=====> Sync complete! Resources: 1 changed, 0 failed" ]]
  
  cleanup_test_app consistent-app
}