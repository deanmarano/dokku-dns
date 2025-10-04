#!/usr/bin/env bats

load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

teardown() {
  # Skip teardown in Docker environment to preserve setup
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

@test "(triggers) post-create trigger exists and is executable" {
  assert_file_exists "$PLUGIN_ROOT/post-create"
  assert_file_executable "$PLUGIN_ROOT/post-create"
}

@test "(triggers) post-delete trigger exists and is executable" {
  assert_file_exists "$PLUGIN_ROOT/post-delete"
  assert_file_executable "$PLUGIN_ROOT/post-delete"
}

@test "(triggers) post-domains-update trigger exists and is executable" {
  assert_file_exists "$PLUGIN_ROOT/post-domains-update"
  assert_file_executable "$PLUGIN_ROOT/post-domains-update"
}

@test "(triggers) post-app-rename trigger exists and is executable" {
  assert_file_exists "$PLUGIN_ROOT/post-app-rename"
  assert_file_executable "$PLUGIN_ROOT/post-app-rename"
}

@test "(triggers) post-create works with no DNS provider configured" {
  # Should not fail even if no provider is configured
  run "$PLUGIN_ROOT/post-create" "test-app"
  assert_success
}

# DNS Trigger Management Tests

@test "(dns:triggers) shows trigger status when disabled by default" {
  run dns_cmd triggers
  assert_success
  assert_output_contains "DNS automatic management: disabled"
}

@test "(dns:triggers) shows disabled status cleanly" {
  run dns_cmd triggers
  assert_success
  assert_output_contains "DNS automatic management: disabled"
}

@test "(dns:triggers:enable) enables triggers successfully" {
  # Verify disabled first
  run dns_cmd triggers
  assert_success
  assert_output_contains "disabled"

  # Enable triggers
  run dns_cmd triggers:enable
  assert_success
  assert_output_contains "DNS automatic management enabled"

  # Verify enabled state file exists
  assert_file_exists "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"
}

@test "(dns:triggers:enable) reports already enabled" {
  # Enable first
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run dns_cmd triggers:enable
  assert_success
  assert_output_contains "DNS automatic management is already enabled"
}

@test "(dns:triggers:disable) disables triggers successfully" {
  # Enable first
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Verify enabled
  run dns_cmd triggers
  assert_success
  assert_output_contains "enabled"

  # Disable triggers
  run dns_cmd triggers:disable
  assert_success
  assert_output_contains "DNS automatic management disabled"

  # Verify state file removed
  assert_file_not_exists "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"
}

@test "(dns:triggers:disable) reports already disabled" {
  # Ensure disabled (should be default)
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run dns_cmd triggers:disable
  assert_success
  assert_output_contains "DNS automatic management is already disabled"
}

@test "(dns:triggers) shows enabled status after enabling" {
  # Enable triggers
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run dns_cmd triggers
  assert_success
  assert_output_contains "DNS automatic management: enabled"
}

@test "(triggers) state persists across command calls" {
  # Start disabled
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"
  run dns_cmd triggers
  assert_success
  assert_output_contains "disabled"

  # Enable
  run dns_cmd triggers:enable
  assert_success

  # Check still enabled
  run dns_cmd triggers
  assert_success
  assert_output_contains "enabled"

  # Disable
  run dns_cmd triggers:disable
  assert_success

  # Check still disabled
  run dns_cmd triggers
  assert_success
  assert_output_contains "disabled"
}

@test "(triggers) post-create works with DNS provider configured when enabled" {
  setup_dns_provider "aws"
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run "$PLUGIN_ROOT/post-create" "test-app"
  assert_success
}

@test "(triggers) post-delete works with app not in DNS management" {
  # Should not fail if app is not managed by DNS
  run "$PLUGIN_ROOT/post-delete" "test-app"
  assert_success
}

@test "(triggers) post-create exits silently when triggers disabled" {
  setup_dns_provider "aws"
  # Ensure triggers are disabled (default state)
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run "$PLUGIN_ROOT/post-create" "test-app"
  assert_success
  # Should have no output when disabled
  [[ -z "$output" ]]
}

@test "(triggers) post-delete exits silently when triggers disabled" {
  setup_dns_provider "aws"
  # Ensure triggers are disabled (default state)
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run "$PLUGIN_ROOT/post-delete" "test-app"
  assert_success
  # Should have no output when disabled
  [[ -z "$output" ]]
}

@test "(triggers) post-delete cleans up DNS management when enabled" {
  setup_dns_provider "aws"
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Simulate app being managed by DNS
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test-app" >"$PLUGIN_DATA_ROOT/LINKS"
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo "example.com" >"$PLUGIN_DATA_ROOT/test-app/DOMAINS"

  run "$PLUGIN_ROOT/post-delete" "test-app"
  assert_success
  assert_output_contains "DNS: Cleaning up DNS management for app 'test-app'"
  assert_output_contains "example.com" 2 # Appears in removal list and cleanup queue

  # Check cleanup happened
  assert_file_not_exists "$PLUGIN_DATA_ROOT/test-app"
  if [[ -f "$PLUGIN_DATA_ROOT/LINKS" ]]; then
    refute_line_in_file "test-app" "$PLUGIN_DATA_ROOT/LINKS"
  fi
}

@test "(triggers) post-domains-update exits silently when triggers disabled" {
  setup_dns_provider "aws"
  # Ensure triggers are disabled (default state)
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run "$PLUGIN_ROOT/post-domains-update" "test-app" "add" "example.com"
  assert_success
  # Should have no output when disabled
  [[ -z "$output" ]]
}

@test "(triggers) post-domains-update works with no DNS provider configured when disabled" {
  # Should not fail even if no provider is configured and triggers are disabled
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"
  run "$PLUGIN_ROOT/post-domains-update" "test-app" "add" "example.com"
  assert_success
  [[ -z "$output" ]]
}

@test "(triggers) post-domains-update adds domain to DNS management when enabled" {
  setup_dns_provider "aws"
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  run "$PLUGIN_ROOT/post-domains-update" "test-app" "add" "example.com"
  assert_success
  assert_output_contains "DNS: Domain 'example.com' added to app 'test-app', checking DNS setup"
  assert_output_contains "DNS: Domain 'example.com' added to DNS tracking"
  assert_output_contains "DNS: Syncing DNS records for 'test-app'"
}

@test "(triggers) post-domains-update remove exits silently when triggers disabled" {
  # Should not fail even if no provider is configured and triggers are disabled
  rm -f "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"
  run "$PLUGIN_ROOT/post-domains-update" "test-app" "remove" "example.com"
  assert_success
  [[ -z "$output" ]]
}

@test "(triggers) post-domains-update removes domain from DNS management when enabled" {
  setup_dns_provider "aws"
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Setup app with domains
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test-app" >"$PLUGIN_DATA_ROOT/LINKS"
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo -e "example.com\napi.example.com" >"$PLUGIN_DATA_ROOT/test-app/DOMAINS"

  run "$PLUGIN_ROOT/post-domains-update" "test-app" "remove" "example.com"
  assert_success
  assert_output_contains "DNS: Domain 'example.com' removed from DNS tracking"

  # Check domain was removed but app still managed
  assert_file_exists "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
  refute_line_in_file "example.com" "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
  assert_line_in_file "api.example.com" "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
}

@test "(triggers) post-domains-update removes app when last domain is removed and enabled" {
  setup_dns_provider "aws"
  mkdir -p "$PLUGIN_DATA_ROOT"
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Setup app with single domain
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test-app" >"$PLUGIN_DATA_ROOT/LINKS"
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo "example.com" >"$PLUGIN_DATA_ROOT/test-app/DOMAINS"

  run "$PLUGIN_ROOT/post-domains-update" "test-app" "remove" "example.com"
  assert_success
  assert_output_contains "DNS: App 'test-app' has no domains left, removing from DNS management"

  # Check app was completely removed
  assert_file_not_exists "$PLUGIN_DATA_ROOT/test-app"
  if [[ -f "$PLUGIN_DATA_ROOT/LINKS" ]]; then
    refute_line_in_file "test-app" "$PLUGIN_DATA_ROOT/LINKS"
  fi
}
