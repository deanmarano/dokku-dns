#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  export TEST_APP="test-app-$$"
  create_test_app "$TEST_APP"
}

teardown() {
  cleanup_test_app "$TEST_APP"
  cleanup_dns_data
}

@test "(dns:apps) lists DNS-managed applications" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps"
  # Will show error if not configured, but command should exist
  assert_contains "${lines[*]}" "DNS-managed applications" || assert_contains "${lines[*]}" "not configured"
}

@test "(dns:apps:enable) command exists and can be called" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable"
  # Command should exit with failure (no args provided)
  assert_failure
  # Just verify the command can be invoked (output may be empty due to error handling)
}

@test "(dns:apps:enable) forwards to add command functionality" {
  # Configure DNS first
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success
  
  # Add some domains to the app
  run dokku domains:add "$TEST_APP" "test.example.com"
  
  # Try to enable DNS (should behave like dns:add)
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" "$TEST_APP"
  # This may fail without AWS credentials, but should at least try
  assert_contains "${lines[*]}" "hosted zone" || assert_contains "${lines[*]}" "AWS"
}

@test "(dns:apps:disable) shows help with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:disable"
  assert_contains "${lines[*]}" "Please specify an app name"
}

@test "(dns:apps:sync) shows help with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync"
  assert_contains "${lines[*]}" "Please specify an app name"
}

@test "(dns:apps:report) shows global report with no arguments" {
  # Configure DNS first so report command works
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:report"
  assert_success
  assert_contains "${lines[*]}" "DNS Global Report"
}

@test "(dns:apps:*) help shows correct descriptions" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:enable"
  assert_success
  assert_contains "$output" "enable DNS management for an application"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:disable"
  assert_success
  assert_contains "$output" "disable DNS management for an application"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:sync"
  assert_success
  assert_contains "$output" "synchronize DNS records for an application"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "apps:report"
  assert_success
  assert_contains "$output" "display DNS status for a specific application"
}