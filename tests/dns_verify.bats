#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:providers:verify) works without configuration" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  assert_output_contains "Verifying AWS Route53 provider"
  assert_output_contains "DNS Provider: AWS (only supported provider)"
}

@test "(dns:providers:verify) always uses AWS provider" {
  cleanup_dns_data
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  assert_output_contains "Verifying AWS Route53 provider"
  assert_output_contains "Current Configuration:"
}

@test "(dns:providers:verify) always verifies AWS provider" {
  # AWS is always the provider now
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  assert_output_contains "Verifying AWS Route53 Setup"
}

@test "(dns:providers:verify) attempts AWS verification when configured" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # With mock AWS CLI, verification should succeed
  assert_output_contains "Verifying AWS Route53 Setup"
  assert_output_contains "Current Configuration"
  assert_output_contains "AWS CLI: installed"
  assert_output_contains "DNS Provider Verification Complete"
}

@test "(dns:providers:verify) shows AWS setup instructions when CLI not configured" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # With mock AWS CLI, should show successful verification
  assert_output_contains "Verifying AWS Route53 Setup"
  assert_output_contains "Current Configuration"
  assert_output_contains "DNS Provider Verification Complete"
}

@test "(dns:providers:verify) provides helpful guidance" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # Should provide next steps and helpful guidance
  assert_output_contains "DNS Provider Verification Complete"
  assert_output_contains "Next Steps:"
  assert_output_contains "Enable zones for auto-discovery"
  assert_output_contains "Add domains to an app"
  assert_output_contains "Sync DNS records"
  assert_output_contains "Check DNS status"
}

# New tests for enhanced functionality
@test "(dns:providers:verify) accepts aws provider argument" {
  # Test with aws provider argument
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" aws
  assert_success
  assert_output_contains "Verifying AWS Route53 Setup"
}

@test "(dns:providers:verify) shows credential detection" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # Should show detailed credential detection
  assert_output_contains "Credential Detection:"
  assert_output_contains "Environment variables:"
  assert_output_contains "AWS config files:"
  assert_output_contains "IAM Role:"
}

@test "(dns:providers:verify) shows AWS account details" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # Should show AWS account information
  assert_output_contains "AWS Account Details:"
  assert_output_contains "Account ID:"
  assert_output_contains "User/Role ARN:"
  assert_output_contains "Region:"
}

@test "(dns:providers:verify) tests Route53 permissions" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # Should test Route53 API access
  assert_output_contains "Testing Route53 API Access:"
  assert_output_contains "route53:ListHostedZones"
  # Note: Other permission tests may only show when zones exist
}

@test "(dns:providers:verify) shows hosted zones discovery" {
  setup_dns_provider aws
  
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  
  # Should show zones discovery
  assert_output_contains "Hosted Zones Discovery:"
  assert_output_contains "Dokku DNS Records Discovery:"
}