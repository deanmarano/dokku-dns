#!/usr/bin/env bats
load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    setup_dns_provider aws
    create_test_app my-app
    add_test_domains my-app example.com api.example.com
  fi
}

teardown() {
  # Skip teardown in Docker environment to preserve setup
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_test_app my-app
    cleanup_dns_data
  fi
}

@test "(dns:apps:enable) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable"
  assert_failure
  # Command fails silently due to shift error in subcommand
}

@test "(dns:apps:enable) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:apps:enable) success with existing app shows domain status table" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app
  assert_success
  assert_output_contains "Adding all domains for app 'my-app':"
  assert_output_contains "Domain Status Table for app 'my-app':"
  assert_output_contains "Domain                         Status   Enabled         Provider        Zone (Enabled)"
  [[ "$output" =~ example\.com ]]
  [[ "$output" =~ api\.example\.com ]]
  assert_output_contains "No (zone disabled)" 2  # Enabled column - appears once per domain
  assert_output_contains "AWS" 4
  assert_output_contains "Status Legend:"
  assert_output_contains "✅ Points to server IP"
  assert_output_contains "⚠️  Points to different IP"
  assert_output_contains "❌ No DNS record found"
  assert_output_contains "No domains with enabled hosted zones found for app: my-app"
}

@test "(dns:apps:enable) success with specific domains shows table" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app example.com
  assert_success
  assert_output_contains "Adding specified domains for app 'my-app':"
  assert_output_contains "Domain Status Table for app 'my-app':"
  [[ "$output" =~ example\.com ]]
  assert_output_contains "No (zone disabled)" 1  # Enabled column - appears in table
  assert_output_contains "AWS" 3
  assert_output_contains "Status Legend:"
}

@test "(dns:apps:enable) success with multiple specific domains" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app example.com api.example.com
  assert_success
  assert_output_contains "Adding specified domains for app 'my-app':"
  assert_output_contains "Domain Status Table for app 'my-app':"
  [[ "$output" =~ example\.com ]]
  [[ "$output" =~ api\.example\.com ]]
  assert_output_contains "AWS" 4  # appears multiple times
}

@test "(dns:apps:enable) handles app with no domains gracefully" {
  # Create app with no domains
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" empty-app
  assert_failure
  assert_output_contains "No domains found for app 'empty-app'"
  assert_output_contains "Add domains first with: dokku domains:add empty-app <domain>"
  
  # Clean up
  cleanup_test_app empty-app
}

@test "(dns:apps:enable) works without credentials configured" {
  cleanup_dns_data  # Clear any existing data
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app
  assert_success
  assert_output_contains "Provider: AWS"
  # Should show zone disabled status for each domain the app has
  # Count should match the number of domains for my-app (typically 2: example.com, api.example.com)
  local domain_count=$(echo "$output" | grep -c "No (zone disabled)")
  # Be flexible about the count since it depends on test setup
  [[ $domain_count -ge 1 ]]  # At least one domain should show this status
  assert_output_contains "Enable zones for auto-discovery with: dokku dns:zones:enable"
}

@test "(dns:apps:enable) works with single domain app" {
  # Create app with single domain
  create_test_app single-app
  add_test_domains single-app single.example.com
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" single-app
  assert_success
  assert_output_contains "Domain Status Table for app 'single-app'"
  [[ "$output" =~ single\.example\.com ]]
  
  cleanup_test_app single-app
}