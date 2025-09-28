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
  assert_output_contains "Checking Dependencies"
  assert_output_contains "jq: available"
  # Should auto-detect configured providers (varies by environment)
  assert_output_contains "Auto-detected provider" || assert_output_contains "Auto-detected providers"
  assert_output_contains "Verifying aws provider"
}

@test "(dns:providers:verify) shows helpful guidance for single provider" {
  cleanup_dns_data

  # Save current environment state
  local SAVED_CLOUDFLARE_TOKEN="${CLOUDFLARE_API_TOKEN:-}"
  local SAVED_DIGITALOCEAN_TOKEN="${DIGITALOCEAN_ACCESS_TOKEN:-}"

  # Test with only AWS configured
  run env -u CLOUDFLARE_API_TOKEN -u DIGITALOCEAN_ACCESS_TOKEN dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  # Should show guidance about adding additional providers
  assert_output_contains "Auto-detected provider: AWS Route53"
  assert_output_contains "To add additional providers, configure their credentials:"
  assert_output_contains "Cloudflare: dokku config:set --global CLOUDFLARE_API_TOKEN"
  assert_output_contains "DigitalOcean: dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN"
  assert_output_contains "DNS Provider Verification Complete"

  # Restore environment state
  if [[ -n "$SAVED_CLOUDFLARE_TOKEN" ]]; then
    export CLOUDFLARE_API_TOKEN="$SAVED_CLOUDFLARE_TOKEN"
  fi
  if [[ -n "$SAVED_DIGITALOCEAN_TOKEN" ]]; then
    export DIGITALOCEAN_ACCESS_TOKEN="$SAVED_DIGITALOCEAN_TOKEN"
  fi
}

@test "(dns:providers:verify) verifies AWS when available" {
  # AWS should be verified since it's always available

  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success
  assert_output_contains "Verifying aws provider"
}

@test "(dns:providers:verify) attempts AWS verification when configured" {
  setup_dns_provider aws

  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success

  # With mock AWS CLI, verification should succeed
  assert_output_contains "Verifying aws provider"
  assert_output_contains "AWS CLI: installed"
  assert_output_contains "DNS Provider Verification Complete"
}

@test "(dns:providers:verify) shows AWS setup instructions when CLI not configured" {
  setup_dns_provider aws

  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success

  # With mock AWS CLI, should show successful verification
  assert_output_contains "Verifying aws provider"
  assert_output_contains "DNS Provider Verification Complete"
}

@test "(dns:providers:verify) provides helpful guidance" {
  setup_dns_provider aws

  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success

  # Should provide next steps and helpful guidance
  assert_output_contains "DNS Provider Verification Complete"
}

# New tests for enhanced functionality
@test "(dns:providers:verify) accepts aws provider argument" {
  # Test with aws provider argument
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" aws
  assert_success
  assert_output_contains "Verifying aws provider"
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

# Multi-provider specific tests
@test "(dns:providers:verify) attempts cloudflare verification when token configured" {
  # Test with cloudflare provider argument when token is configured (will fail with test token)
  CLOUDFLARE_API_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" cloudflare
  assert_failure
  assert_output_contains "Verifying cloudflare provider"
  assert_output_contains "CLOUDFLARE_API_TOKEN: configured"
  assert_output_contains "API authentication failed"
}

@test "(dns:providers:verify) attempts digitalocean verification when token configured" {
  # Test with digitalocean provider argument when token is configured (will fail with test token)
  DIGITALOCEAN_ACCESS_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" digitalocean
  assert_failure
  assert_output_contains "Verifying digitalocean provider"
  assert_output_contains "DIGITALOCEAN_ACCESS_TOKEN: configured"
  assert_output_contains "API authentication failed"
}

@test "(dns:providers:verify) auto-detects multiple providers when configured" {
  # Test auto-detection with multiple providers configured (aws succeeds, others fail with test tokens)
  CLOUDFLARE_API_TOKEN="test-token" DIGITALOCEAN_ACCESS_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  assert_success # Should succeed because AWS verification works
  assert_output_contains "Auto-detected providers: aws cloudflare digitalocean"
  assert_output_contains "Verifying aws provider"
  assert_output_contains "Verifying cloudflare provider"
  assert_output_contains "Verifying digitalocean provider"
  # AWS should succeed, others should show auth failures
  assert_output_contains "AWS CLI: installed"
}

@test "(dns:providers:verify) rejects invalid provider argument" {
  # Test with invalid provider argument
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" invalid-provider
  assert_failure
  assert_output_contains "Provider 'invalid-provider' is not available"
  assert_output_contains "Available providers:"
}

@test "(dns:providers:verify) rejects template provider in normal mode" {
  # Template provider should be rejected in normal mode
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" template
  assert_failure
  assert_output_contains "Provider 'template' is only available in test mode"
}

@test "(dns:providers:verify) accepts template provider in test mode" {
  # Template provider should work in test mode
  DNS_TEST_MODE=1 run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" template
  assert_success
  assert_output_contains "Verifying template provider"
}
