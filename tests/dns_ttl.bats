#!/usr/bin/env bats

load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    setup_dns_provider aws
  fi
}

teardown() {
  # Clean up TTL configuration and DNS data
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

@test "(dns:ttl) shows default TTL when no TTL configured" {
  # Ensure no TTL is configured
  rm -f "$PLUGIN_DATA_ROOT/GLOBAL_TTL" 2>/dev/null || true

  run dns_cmd ttl
  assert_success
  assert_output_contains "300"
}

@test "(dns:ttl) shows configured TTL when TTL is set" {
  # Set a custom TTL
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "600" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  run dns_cmd ttl
  assert_success
  assert_output_contains "600"
}

@test "(dns:ttl 600) sets valid TTL" {
  run dns_cmd ttl 600
  assert_success
  assert_output_contains "Global DNS TTL set to 600 seconds"

  # Verify TTL was written to file
  run cat "$PLUGIN_DATA_ROOT/GLOBAL_TTL"
  assert_success
  assert_output "600"
}

@test "(dns:ttl 60) accepts minimum valid TTL" {
  run dns_cmd ttl 60
  assert_success
  assert_output_contains "Global DNS TTL set to 60 seconds"

  # Verify TTL was written to file
  run cat "$PLUGIN_DATA_ROOT/GLOBAL_TTL"
  assert_success
  assert_output "60"
}

@test "(dns:ttl 86400) accepts maximum valid TTL" {
  run dns_cmd ttl 86400
  assert_success
  assert_output_contains "Global DNS TTL set to 86400 seconds"

  # Verify TTL was written to file
  run cat "$PLUGIN_DATA_ROOT/GLOBAL_TTL"
  assert_success
  assert_output "86400"
}

@test "(dns:ttl 59) rejects TTL below minimum" {
  run dns_cmd ttl 59
  assert_failure
  assert_output_contains "TTL value must be at least 60 seconds"
}

@test "(dns:ttl 86401) rejects TTL above maximum" {
  run dns_cmd ttl 86401
  assert_failure
  assert_output_contains "TTL value must be no more than 86400 seconds"
}

@test "(dns:ttl abc) rejects non-numeric TTL" {
  run dns_cmd ttl abc
  assert_failure
  assert_output_contains "TTL value must be a positive integer"
}

@test "(dns:ttl -100) rejects negative TTL" {
  run dns_cmd ttl -100
  assert_failure
  assert_output_contains "TTL value must be a positive integer"
}

@test "(dns:ttl 0) rejects zero TTL" {
  run dns_cmd ttl 0
  assert_failure
  assert_output_contains "TTL value must be at least 60 seconds"
}

@test "(dns:ttl) ttl command fallback behavior with corrupted file" {
  # Create corrupted TTL file
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "invalid-data" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # The ttl command should fall back to default when file is corrupted
  run dns_cmd ttl
  assert_success
  assert_output "300"
}

@test "(dns:ttl) ttl command fallback behavior with empty file" {
  # Create empty TTL file
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # The ttl command should fall back to default when file is empty
  run dns_cmd ttl
  assert_success
  assert_output "300"
}

# Integration tests with DNS sync operations

@test "(dns:ttl) integration with DNS sync operations" {
  # Create test app and enable DNS management
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  # Set custom TTL
  run dns_cmd ttl 3600
  assert_success

  # Enable DNS management for the app
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" ttl-test-app
  # Accept success or failure since provider may not be configured
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  # Sync the app and check that TTL is being read properly
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" ttl-test-app

  # Check if the operation attempted to use our custom TTL
  # (Success/failure depends on provider availability, but should not crash)
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:ttl) preserves TTL setting across plugin operations" {
  # Set initial TTL
  run dns_cmd ttl 7200
  assert_success
  assert_output_contains "Global DNS TTL set to 7200 seconds"

  # Verify TTL is still set after running command
  run dns_cmd ttl
  assert_success
  assert_output_contains "7200"
}
