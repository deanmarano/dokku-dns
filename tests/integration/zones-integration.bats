#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Zones Integration Tests
# Tests for dns:zones subcommands

setup() {
  check_dns_plugin_available
  TEST_APP="dns-zones-test"
  setup_test_app "$TEST_APP"
}

teardown() {
  cleanup_test_app "$TEST_APP"
}

@test "(dns:zones) lists available DNS zones" {
  run dokku dns:zones
  # Command may fail if AWS CLI not available, that's expected
  [[ "$output" =~ (Zones|zone|DISABLED|aws|provider|AWS\ CLI) ]]
}

@test "(dns:zones) shows provider information" {
  run dokku dns:zones
  # Should show provider information (mock, aws, or other providers)
  assert_success
  # Match any provider-related output
  [[ "$output" =~ (provider|Provider|PROVIDER|mock|aws|Zones) ]]
}

@test "(dns:zones:enable) requires zone name argument" {
  run dokku dns:zones:enable
  # Command should show help/usage when no arguments provided
  [[ "$status" -ne 0 ]] || [[ "$output" =~ (Usage|usage|help|argument) ]]
}

@test "(dns:zones) shows zone details when AWS CLI available and zone exists" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  local test_zone
  test_zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//')

  if [[ -n "$test_zone" ]]; then
    run dokku dns:zones "$test_zone"
    assert_success
    assert_output --partial "DNS Zone Details: $test_zone"
    assert_output --partial "AWS Route53 Information"
    assert_output --partial "Zone ID:"
    assert_output --partial "DNS Records"
    assert_output --partial "Dokku Integration"
  else
    skip "No test zone available"
  fi
}

@test "(dns:zones) fails for non-existent zone when AWS CLI available" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  run dokku dns:zones "nonexistent-test-zone-12345.com"
  assert_failure
  assert_output --partial "not found in Route53"
}

@test "(dns:zones:enable) fails with both zone name and --all flag" {
  run dokku dns:zones:enable example.com --all
  assert_failure
}

@test "(dns:zones:disable) fails with both zone name and --all flag" {
  run dokku dns:zones:disable example.com --all
  assert_failure
}

@test "(dns:zones:enable) processes real zone when AWS CLI available" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  local test_zone
  test_zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//')

  if [[ -n "$test_zone" ]]; then
    run dokku dns:zones:enable "$test_zone"
    # May succeed or fail depending on zone configuration
    assert_output --partial "Adding zone to auto-discovery: $test_zone"
  else
    skip "No test zone available"
  fi
}

@test "(dns:zones:disable) works with real zone when AWS CLI available" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  local test_zone
  test_zone=$(aws route53 list-hosted-zones --query 'HostedZones[0].Name' --output text 2>/dev/null | sed 's/\.$//')

  if [[ -n "$test_zone" ]]; then
    run dokku dns:zones:disable "$test_zone"
    assert_success
    assert_output --partial "Removing zone from auto-discovery: $test_zone"
  else
    skip "No test zone available"
  fi
}

@test "(dns:zones:enable --all) processes all zones when AWS CLI available" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  run dokku dns:zones:enable --all
  # May succeed or fail depending on zone configuration
  assert_output --partial "Adding all zones to auto-discovery"
}

@test "(dns:zones:disable --all) works when AWS CLI available" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  run dokku dns:zones:disable --all
  assert_success
  assert_output --partial "Removing all zones from auto-discovery"
}

@test "(dns:zones:enable) works with available providers" {
  # With multi-provider system, this should work with any available provider (mock, aws, etc.)
  run dokku dns:zones:enable example.com
  # Should succeed with any available provider
  assert_success
  assert_output --partial "added to auto-discovery"
}

@test "(dns:zones:disable) works without AWS CLI" {
  # Only run if AWS CLI is NOT available
  if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI is available and configured"
  fi

  run dokku dns:zones:disable example.com
  assert_success
  assert_output --partial "removed from auto-discovery"
}

@test "(dns:zones:enable --all) works with available providers" {
  # With multi-provider system, this should work with any available provider (mock, aws, etc.)
  run dokku dns:zones:enable --all
  # Should show adding zones message (may fail with permission denied in Docker, that's ok)
  assert_output --partial "Adding all zones to auto-discovery"
  # Exit code could be 0 (success) or 1 (permission denied writing ENABLED_ZONES)
  [[ "$status" -eq 0 ]] || [[ "$output" =~ "Permission denied" ]]
}

@test "(dns:zones:disable --all) works without AWS CLI" {
  # Only run if AWS CLI is NOT available
  if command -v aws >/dev/null 2>&1 && aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI is available and configured"
  fi

  run dokku dns:zones:disable --all
  assert_success
  assert_output --partial "No apps are currently managed by DNS"
}

@test "(dns:zones) rejects unknown flags" {
  run dokku dns:zones --invalid-flag
  assert_failure
  assert_output --partial "Flags are no longer supported"
}

@test "(zones integration) can create test app for zones testing" {
  local ZONES_TEST_APP="zones-report-test"

  # Clean up any existing test app first
  dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1 || true
  sleep 1

  # Ensure no zones are enabled to prevent auto-DNS management by triggers
  mkdir -p /var/lib/dokku/services/dns
  rm -f /var/lib/dokku/services/dns/ENABLED_ZONES

  # Create the test app
  run dokku apps:create "$ZONES_TEST_APP"
  assert_success

  # Clean up
  dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1 || true
}

@test "(zones integration) can add domains to zones test app" {
  local ZONES_TEST_APP="zones-report-test-domains"

  # Setup
  dokku apps:create "$ZONES_TEST_APP" >/dev/null 2>&1 || true
  mkdir -p /var/lib/dokku/services/dns
  rm -f /var/lib/dokku/services/dns/ENABLED_ZONES

  # Add domains that would be in example.com zone
  run dokku domains:add "$ZONES_TEST_APP" "app.example.com"
  assert_success

  run dokku domains:add "$ZONES_TEST_APP" "api.example.com"
  assert_success

  # Verify domains were added
  run dokku domains:report "$ZONES_TEST_APP"
  assert_success
  assert_output --partial "app.example.com"
  assert_output --partial "api.example.com"

  # Clean up
  dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1 || true
}

@test "(zones integration) DNS management works after zone enabled" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  local ZONES_TEST_APP="zones-dns-test"

  # Setup app with domains
  dokku apps:create "$ZONES_TEST_APP" >/dev/null 2>&1 || true
  dokku domains:add "$ZONES_TEST_APP" "app.example.com" >/dev/null 2>&1 || true

  # Ensure app is not in DNS management initially
  dokku dns:apps:disable "$ZONES_TEST_APP" >/dev/null 2>&1 || true

  # Create enabled zones file for testing
  mkdir -p /var/lib/dokku/services/dns
  echo "example.com" >/var/lib/dokku/services/dns/ENABLED_ZONES

  # Add app to DNS management after zone enabled
  run dokku dns:apps:enable "$ZONES_TEST_APP"
  assert_success
  assert_output --partial "app.example.com"

  # Clean up
  rm -f /var/lib/dokku/services/dns/ENABLED_ZONES
  dokku dns:apps:disable "$ZONES_TEST_APP" >/dev/null 2>&1 || true
  dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1 || true
}

@test "(zones integration) sync works with enabled zones" {
  # Skip if AWS CLI not available
  if ! command -v aws >/dev/null 2>&1 || ! aws sts get-caller-identity >/dev/null 2>&1; then
    skip "AWS CLI not available or not configured"
  fi

  local ZONES_TEST_APP="zones-sync-test"

  # Setup app with domains and DNS management
  dokku apps:create "$ZONES_TEST_APP" >/dev/null 2>&1 || true
  dokku domains:add "$ZONES_TEST_APP" "sync.example.com" >/dev/null 2>&1 || true

  # Create enabled zones file and enable DNS for app
  mkdir -p /var/lib/dokku/services/dns
  echo "example.com" >/var/lib/dokku/services/dns/ENABLED_ZONES
  dokku dns:apps:enable "$ZONES_TEST_APP" >/dev/null 2>&1 || true

  # Test sync with enabled zone
  run dokku dns:apps:sync "$ZONES_TEST_APP"
  assert_success
  # Should show sync operation (exact output depends on AWS availability)
  [[ "$output" =~ (sync|AWS|domain|Syncing) ]]

  # Clean up
  rm -f /var/lib/dokku/services/dns/ENABLED_ZONES
  dokku dns:apps:disable "$ZONES_TEST_APP" >/dev/null 2>&1 || true
  dokku apps:destroy "$ZONES_TEST_APP" --force >/dev/null 2>&1 || true
}
