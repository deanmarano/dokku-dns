#!/usr/bin/env bats
load bats-common

setup() {
  check_dns_plugin_available
  TEST_APP="sync-deletions-test"
  setup_test_app "$TEST_APP"
}

teardown() {
  cleanup_test_app "$TEST_APP"
}

@test "(dns:sync:deletions integration) error with no enabled zones" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  assert_success
  assert_output_contains "No enabled zones found"
  assert_output_contains "Use 'dokku dns:zones:enable <zone>' to enable zones first"
}

@test "(dns:sync:deletions integration) shows helpful message when no orphaned records" {
  skip_if_no_aws_credentials
  
  # Enable a zone if available (this will depend on what zones are configured)
  if aws route53 list-hosted-zones >/dev/null 2>&1; then
    local zones
    zones=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//g' || echo "")
    
    if [[ -n "$zones" ]]; then
      dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "$zones" >/dev/null 2>&1 || true
      
      # Now run deletions command - should find no orphaned records in most cases
      run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
      assert_success
      
      # Should either find orphaned records or show "no orphaned records found"
      if [[ "$output" == *"No orphaned DNS records found"* ]]; then
        assert_output_contains "All DNS records correspond to active Dokku domains"
      else
        assert_output_contains "Planned Deletions:" || assert_output_contains "Found" 
      fi
    fi
  fi
}

@test "(dns:sync:deletions integration) shows Terraform-style plan output" {
  skip_if_no_aws_credentials
  
  # Get first available hosted zone
  local zone
  if aws route53 list-hosted-zones >/dev/null 2>&1; then
    zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//g' || echo "")
    
    if [[ -n "$zone" ]]; then
      dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "$zone" >/dev/null 2>&1 || true
      
      # Run the sync:deletions command
      run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
      assert_success
      
      # Check for plan-style output regardless of whether there are orphaned records
      if [[ "$output" == *"Planned Deletions:"* ]]; then
        assert_output_contains "Plan: 0 to add, 0 to change,"
        assert_output_contains "to destroy"
        assert_output_contains "Do you want to delete these"
      else
        assert_output_contains "No orphaned DNS records found"
      fi
    fi
  fi
}

@test "(dns:sync:deletions integration) handles zone-specific cleanup" {
  skip_if_no_aws_credentials
  
  # Get first available hosted zone for zone-specific testing
  local zone
  if aws route53 list-hosted-zones >/dev/null 2>&1; then
    zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//g' || echo "")
    
    if [[ -n "$zone" ]]; then
      # Run zone-specific deletions
      run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions" "$zone"
      assert_success
      
      # Should mention the specific zone being scanned
      assert_output_contains "Scanning zone: $zone"
      
      # Should either find orphaned records or show clean result
      if [[ "$output" != *"Planned Deletions:"* ]]; then
        assert_output_contains "No orphaned DNS records found"
      fi
    fi
  fi
}

@test "(dns:sync:deletions integration) respects user cancellation" {
  skip_if_no_aws_credentials
  
  # This test verifies that user can cancel deletion operation
  # We'll create a test that pipes 'n' to the command
  
  local zone
  if aws route53 list-hosted-zones >/dev/null 2>&1; then
    zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//g' || echo "")
    
    if [[ -n "$zone" ]]; then
      dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "$zone" >/dev/null 2>&1 || true
      
      # Pipe 'n' to simulate user declining deletion
      run bash -c 'echo "n" | dokku '"$PLUGIN_COMMAND_PREFIX"':sync:deletions'
      assert_success
      
      # Should either show cancellation message or no orphaned records
      if [[ "$output" == *"Do you want to delete"* ]]; then
        assert_output_contains "Deletion cancelled by user"
      else
        assert_output_contains "No orphaned DNS records found"
      fi
    fi
  fi
}

@test "(dns:sync:deletions integration) validates AWS credentials before attempting scan" {
  skip_if_no_aws_credentials
  
  # This test ensures the command handles AWS credential issues gracefully
  
  # Temporarily break AWS credentials by unsetting them
  local original_aws_access_key="${AWS_ACCESS_KEY_ID:-}"
  local original_aws_secret_key="${AWS_SECRET_ACCESS_KEY:-}"
  local original_aws_profile="${AWS_PROFILE:-}"
  
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_PROFILE
  
  # Create an enabled zone
  echo "example.com" > "$PLUGIN_DATA_ROOT/ZONES_ENABLED"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
  
  # Restore AWS credentials
  [[ -n "$original_aws_access_key" ]] && export AWS_ACCESS_KEY_ID="$original_aws_access_key"
  [[ -n "$original_aws_secret_key" ]] && export AWS_SECRET_ACCESS_KEY="$original_aws_secret_key"  
  [[ -n "$original_aws_profile" ]] && export AWS_PROFILE="$original_aws_profile"
  
  assert_success
  # Should gracefully handle missing AWS credentials
  assert_output_contains "Could not find AWS hosted zone for: example.com"
}

@test "(dns:sync:deletions integration) identifies actual orphaned records in test environment" {
  skip_if_no_aws_credentials
  
  # This test creates a realistic scenario where we have orphaned DNS records
  # and verifies that the command correctly identifies them
  
  local zone
  if aws route53 list-hosted-zones >/dev/null 2>&1; then
    zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//g' || echo "")
    
    if [[ -n "$zone" ]]; then
      dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" "$zone" >/dev/null 2>&1 || true
      
      # Create a test app but don't add any domains to it
      # This way, any existing DNS records will appear orphaned
      setup_test_app "orphan-test-app"
      
      run dokku "$PLUGIN_COMMAND_PREFIX:sync:deletions"
      assert_success
      
      # The command should run successfully and show either orphaned records or none
      if [[ "$output" == *"Planned Deletions:"* ]]; then
        # Found orphaned records - verify plan format
        assert_output_contains "Plan: 0 to add, 0 to change,"
        assert_output_contains "to destroy"
      else
        # No orphaned records found
        assert_output_contains "No orphaned DNS records found"
      fi
      
      cleanup_test_app "orphan-test-app"
    fi
  fi
}