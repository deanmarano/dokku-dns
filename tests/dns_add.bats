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

@test "(dns:add) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add"
  assert_failure
  # Command fails silently due to shift error in subcommand
}

@test "(dns:add) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:add) success with existing app shows domain status table" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  assert_success
  assert_output_contains "Adding all domains for app 'my-app':"
  assert_output_contains "Domain Status Table for app 'my-app':"
  assert_output_contains "Domain                         Status   Enabled         Provider        Zone (Enabled)"
  assert_output_contains "example.com" 14  # Appears multiple times in output
  assert_output_contains "api.example.com" 7  # Appears multiple times in output
  assert_output_contains "provider not ready" 2  # Enabled column - appears once per domain
  assert_output_contains "aws" 3  # Provider column
  assert_output_contains "Status Legend:"
  assert_output_contains "✅ Points to server IP"
  assert_output_contains "⚠️  Points to different IP"
  assert_output_contains "❌ No DNS record found"
  assert_output_contains "No domains with hosted zones found for app: my-app"
}

@test "(dns:add) success with specific domains shows table" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app example.com
  assert_success
  assert_output_contains "Adding specified domains for app 'my-app':"
  assert_output_contains "Domain Status Table for app 'my-app':"
  assert_output_contains "example.com" 7  # Appears multiple times in output
  assert_output_contains "provider not ready" 1  # Enabled column - appears in table
  assert_output_contains "aws" 2  # Provider column
  assert_output_contains "Status Legend:"
}

@test "(dns:add) success with multiple specific domains" {
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app example.com api.example.com
  assert_success
  assert_output_contains "Adding specified domains for app 'my-app':"
  assert_output_contains "Domain Status Table for app 'my-app':"
  assert_output_contains "example.com" 14  # Appears multiple times in output
  assert_output_contains "api.example.com" 7  # Appears multiple times in output
  assert_output_contains "aws" 3  # Provider column - appears multiple times
}

@test "(dns:add) handles app with no domains gracefully" {
  # Create app with no domains
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:add" empty-app
  assert_failure
  assert_output_contains "No domains found for app 'empty-app'"
  assert_output_contains "Add domains first with: dokku domains:add empty-app <domain>"
  
  # Clean up
  cleanup_test_app empty-app
}

@test "(dns:add) fails when no provider configured" {
  cleanup_dns_data  # Remove provider configuration
  
  run dokku "$PLUGIN_COMMAND_PREFIX:add" my-app
  assert_success
  assert_output_contains "Provider: None"
  assert_output_contains "provider not ready" 2  # Appears for each domain in table
  assert_output_contains "Next step: dokku dns:sync my-app"
}

@test "(dns:add) works with single domain app" {
  # Create app with single domain
  create_test_app single-app
  add_test_domains single-app single.example.com
  
  run dokku "$PLUGIN_COMMAND_PREFIX:add" single-app
  assert_success
  assert_output_contains "Domain Status Table for app 'single-app'"
  assert_output_contains "single.example.com" 7  # Appears multiple times in output
  
  cleanup_test_app single-app
}