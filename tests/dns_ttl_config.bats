#!/usr/bin/env bats

load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    setup_dns_provider aws
  fi

  # Clean up any existing global config
  dokku config:unset --global DNS_DEFAULT_TTL DNS_MIN_TTL DNS_MAX_TTL 2>/dev/null || true
}

teardown() {
  # Clean up TTL configuration and DNS data
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi

  # Clean up global config
  dokku config:unset --global DNS_DEFAULT_TTL DNS_MIN_TTL DNS_MAX_TTL 2>/dev/null || true
}

@test "(dns:ttl config) get_dns_ttl_config returns default values" {
  # Source functions to get access to helper
  source "$PLUGIN_DIR/functions"

  run get_dns_ttl_config "default"
  assert_success
  assert_output "300"

  run get_dns_ttl_config "min"
  assert_success
  assert_output "60"

  run get_dns_ttl_config "max"
  assert_success
  assert_output "86400"
}

@test "(dns:ttl config) get_dns_ttl_config reads from dokku config" {
  # Set custom values via dokku config
  dokku config:set --global DNS_DEFAULT_TTL=600
  dokku config:set --global DNS_MIN_TTL=120
  dokku config:set --global DNS_MAX_TTL=43200

  # Source functions to get access to helper
  source "$PLUGIN_DIR/functions"

  run get_dns_ttl_config "default"
  assert_success
  assert_output "600"

  run get_dns_ttl_config "min"
  assert_success
  assert_output "120"

  run get_dns_ttl_config "max"
  assert_success
  assert_output "43200"
}

@test "(dns:ttl config) custom default TTL is used by ttl command" {
  # Set custom default via dokku config
  dokku config:set --global DNS_DEFAULT_TTL=600

  # Remove any existing TTL file
  rm -f "$PLUGIN_DATA_ROOT/GLOBAL_TTL" 2>/dev/null || true

  # Get TTL - should return custom default
  run dns_cmd ttl
  assert_success
  assert_output "600"
}

@test "(dns:ttl config) custom min TTL is enforced in validation" {
  # Set custom minimum to 120 seconds
  dokku config:set --global DNS_MIN_TTL=120

  # Try to set TTL below custom minimum
  run dns_cmd ttl 100
  assert_failure
  assert_output_contains "TTL value must be at least 120 seconds"

  # Verify we can set exactly at the minimum
  run dns_cmd ttl 120
  assert_success
  assert_output_contains "Global DNS TTL set to 120 seconds"
}

@test "(dns:ttl config) custom max TTL is enforced in validation" {
  # Set custom maximum to 43200 seconds (12 hours)
  dokku config:set --global DNS_MAX_TTL=43200

  # Try to set TTL above custom maximum
  run dns_cmd ttl 50000
  assert_failure
  assert_output_contains "TTL value must be no more than 43200 seconds"

  # Verify we can set exactly at the maximum
  run dns_cmd ttl 43200
  assert_success
  assert_output_contains "Global DNS TTL set to 43200 seconds"
}

@test "(dns:zones:ttl config) custom min TTL is enforced in validation" {
  # Set custom minimum to 120 seconds
  dokku config:set --global DNS_MIN_TTL=120

  # Try to set zone TTL below custom minimum
  run dns_cmd zones:ttl example.com 100
  assert_failure
  assert_output_contains "TTL value must be at least 120 seconds"

  # Verify we can set exactly at the minimum
  run dns_cmd zones:ttl example.com 120
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 120 seconds"
}

@test "(dns:zones:ttl config) custom max TTL is enforced in validation" {
  # Set custom maximum to 43200 seconds (12 hours)
  dokku config:set --global DNS_MAX_TTL=43200

  # Try to set zone TTL above custom maximum
  run dns_cmd zones:ttl example.com 50000
  assert_failure
  assert_output_contains "TTL value must be no more than 43200 seconds"

  # Verify we can set exactly at the maximum
  run dns_cmd zones:ttl example.com 43200
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 43200 seconds"
}

@test "(dns:ttl config) file-based TTL takes precedence over config default" {
  # Set custom default via dokku config
  dokku config:set --global DNS_DEFAULT_TTL=600

  # Set TTL via file (should take precedence)
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "1200" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # Get TTL - should return file value, not config default
  run dns_cmd ttl
  assert_success
  assert_output "1200"
}

@test "(dns:ttl config) fallback to config default when file is invalid" {
  # Set custom default via dokku config
  dokku config:set --global DNS_DEFAULT_TTL=600

  # Create corrupted TTL file
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "invalid-data" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # Get TTL - should fall back to config default
  run dns_cmd ttl
  assert_success
  assert_output "600"
}

@test "(dns:ttl config) config changes take effect immediately" {
  # Set initial custom values
  dokku config:set --global DNS_MIN_TTL=120
  dokku config:set --global DNS_MAX_TTL=43200

  # Verify validation uses initial values
  run dns_cmd ttl 100
  assert_failure
  assert_output_contains "at least 120 seconds"

  # Change minimum to lower value
  dokku config:set --global DNS_MIN_TTL=90

  # Now 100 should be valid
  run dns_cmd ttl 100
  assert_success
  assert_output_contains "Global DNS TTL set to 100 seconds"
}
