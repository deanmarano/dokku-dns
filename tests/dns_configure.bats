#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:configure) success with no arguments (uses default)" {
  run dokku "$PLUGIN_COMMAND_PREFIX:configure"
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
  assert_output_contains "Next step: dokku dns:verify"
}

@test "(dns:configure) error when invalid provider specified" {
  run dokku "$PLUGIN_COMMAND_PREFIX:configure" invalid-provider
  assert_failure
  assert_output_contains "Invalid provider 'invalid-provider'"
  assert_output_contains "Supported providers: aws, cloudflare"
}

@test "(dns:configure) success with aws provider" {
  run dokku "$PLUGIN_COMMAND_PREFIX:configure" aws
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
  assert_output_contains "Next step: dokku dns:verify"
  
  # Verify the provider file was created
  assert_exists "$PLUGIN_DATA_ROOT/PROVIDER"
  
  # Check the content
  run cat "$PLUGIN_DATA_ROOT/PROVIDER"
  assert_success
  assert_output "aws"
}


@test "(dns:configure) success with default provider (no args)" {
  run dokku "$PLUGIN_COMMAND_PREFIX:configure"
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
  assert_output_contains "Next step: dokku dns:verify"
  
  # Check default provider was set
  run cat "$PLUGIN_DATA_ROOT/PROVIDER"
  assert_success
  assert_output "aws"
}


@test "(dns:configure) creates data directory if missing" {
  # Ensure directory doesn't exist
  rm -rf "$PLUGIN_DATA_ROOT"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:configure" aws
  assert_success
  
  # Verify directory was created
  [ -d "$PLUGIN_DATA_ROOT" ]
}