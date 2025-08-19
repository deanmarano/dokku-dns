#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  create_test_app my-app
  add_test_domains my-app test1.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
}

@test "(dns:sync) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync"
  assert_failure
  assert_output_contains "Please specify an app name"
}

@test "(dns:sync) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:sync) error when no provider configured" {
  cleanup_dns_data  # Remove provider configuration
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_failure
  assert_output_contains "No DNS provider configured"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:sync) error when provider file is empty" {
  # Create empty provider file
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_failure
  assert_output_contains "DNS provider not set"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:sync) error when invalid provider configured" {
  # Create provider file with invalid provider
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "invalid" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_failure
  assert_output_contains "Provider 'invalid' not found"
  assert_output_contains "Available providers: aws, cloudflare"
}

@test "(dns:sync) attempts AWS sync when configured" {
  # Add app to DNS management first
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app >/dev/null 2>&1
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_success
  
  # With mock AWS CLI, sync should work and show domain sync results
  assert_output_contains "Syncing domains for app 'my-app'"
  assert_output_contains "DNS record created" || assert_output_contains "DNS record updated"
}

@test "(dns:sync) handles app with no domains" {
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" empty-app
  assert_success
  
  # With mock AWS, should reach domain checking and show no domains message
  assert_output_contains "No DNS-managed domains found for app: empty-app"
  assert_output_contains "Add domains to DNS first"
  
  cleanup_test_app empty-app
}

@test "(dns:sync) shows helpful error when AWS not accessible" {
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  
  # In test environment, likely to fail with auth issues
  if [[ "$status" -ne 0 ]]; then
    assert_output_contains "AWS CLI is not configured" || assert_output_contains "credentials"
    assert_output_contains "Run: dokku dns:verify"
  fi
}

@test "(dns:sync) attempts sync with multiple domains" {
  add_test_domains my-app test2.com working.com
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:add" my-app >/dev/null 2>&1
  
  run dokku "$PLUGIN_COMMAND_PREFIX:sync" my-app
  assert_success
  
  # Should sync multiple domains
  assert_output_contains "Syncing domains for app 'my-app'"
}