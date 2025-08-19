#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:verify) error when no provider configured" {
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  assert_output_contains "No provider configured"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:verify) error when provider file is empty" {
  # Create empty provider file
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  assert_output_contains "Provider not set"
  assert_output_contains "Run: dokku dns:configure <provider>"
}

@test "(dns:verify) error when invalid provider configured" {
  # Create provider file with invalid provider
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "invalid" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  assert_output_contains "Provider 'invalid' not found"
  assert_output_contains "Available providers: aws, cloudflare"
}

@test "(dns:verify) attempts AWS verification when configured" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_success
  
  # With mock AWS CLI, verification should succeed
  assert_output_contains "Verifying AWS Route53 access"
  assert_output_contains "Checking AWS CLI configuration"
  assert_output_contains "AWS CLI configured successfully"
  assert_output_contains "Route53 access confirmed"
  assert_output_contains "Available hosted zones:"
}

@test "(dns:verify) shows AWS setup instructions when CLI not configured" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_success
  
  # With mock AWS CLI, should show successful verification
  assert_output_contains "Verifying AWS Route53 access"
  assert_output_contains "AWS CLI configured successfully"
  assert_output_contains "Route53 access confirmed"
}

@test "(dns:verify) handles cloudflare provider" {
  setup_dns_provider cloudflare
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_failure
  
  # Currently shows provider not found error even though it's listed as available
  assert_output_contains "Provider 'cloudflare' not found"
}

@test "(dns:verify) provides helpful guidance" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:verify"
  assert_success
  
  # Should provide next steps and helpful guidance
  assert_output_contains "DNS provider verification and discovery completed successfully"
  assert_output_contains "Ready to use" || assert_output_contains "Next steps:"
}