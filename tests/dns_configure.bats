#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:providers:configure) success with no arguments (uses default)" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure"
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
  assert_output_contains "Next step: dokku dns:providers:verify"
}

@test "(dns:providers:configure) error when invalid provider specified" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" invalid-provider
  assert_failure
  assert_output_contains "Invalid provider 'invalid-provider'"
  assert_output_contains "Supported providers: aws, cloudflare"
}

@test "(dns:providers:configure) success with aws provider" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
  assert_output_contains "Next step: dokku dns:providers:verify"
  
  # Verify the provider file was created
  assert_exists "$PLUGIN_DATA_ROOT/PROVIDER"
  
  # Check the content
  run cat "$PLUGIN_DATA_ROOT/PROVIDER"
  assert_success
  assert_output "aws"
}


@test "(dns:providers:configure) success with default provider (no args)" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure"
  assert_success
  assert_output_contains "DNS configured globally with provider: aws"
  assert_output_contains "Next step: dokku dns:providers:verify"
  
  # Check default provider was set
  run cat "$PLUGIN_DATA_ROOT/PROVIDER"
  assert_success
  assert_output "aws"
}


@test "(dns:providers:configure) creates data directory if missing" {
  # Ensure directory doesn't exist
  rm -rf "$PLUGIN_DATA_ROOT"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:configure" aws
  assert_success
  
  # Verify directory was created
  [ -d "$PLUGIN_DATA_ROOT" ]
}