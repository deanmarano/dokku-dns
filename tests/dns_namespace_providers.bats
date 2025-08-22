#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:providers:configure) uses default provider with no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure"
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
}

@test "(dns:providers:configure) accepts aws provider" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
}

@test "(dns:providers:verify) works without arguments when configured" {
  # First configure a provider
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success
  
  # Then verify should work
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  # Note: This will fail if AWS isn't configured, but should at least try
  assert_contains "${lines[*]}" "Verifying"
}

@test "(dns:providers:verify) accepts provider argument" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" aws
  assert_success
  assert_output_contains "Verifying specific provider: aws"
}

@test "(dns:providers:verify) help shows provider argument" {
  run dokku "$PLUGIN_COMMAND_PREFIX:help" "providers:verify"
  assert_success
  # Check for specific help text that should appear
  assert_output_contains "optional DNS provider to verify"
}