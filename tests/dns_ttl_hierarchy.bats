#!/usr/bin/env bats

load test_helper

# Tests for TTL hierarchy: domain -> zone -> global -> default
# And per-domain/per-zone TTL commands

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  export PLUGIN_DATA_ROOT
}

teardown() {
  cleanup_dns_data
}

# Zone TTL command tests

@test "(dns:zones:ttl) sets and gets zone TTL" {
  run dns_cmd zones:ttl example.com 3600
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 3600 seconds"

  run dns_cmd zones:ttl example.com
  assert_success
  assert_output "3600"
}

@test "(dns:zones:ttl) fails when no TTL configured for zone" {
  run dns_cmd zones:ttl example.com
  assert_failure
  assert_output_contains "No TTL configured for zone: example.com"
}

@test "(dns:zones:ttl) requires zone parameter" {
  run dns_cmd zones:ttl
  assert_failure
  assert_output_contains "Please specify a zone name"
}

@test "(dns:zones:ttl) validates zone format" {
  run dns_cmd zones:ttl invalid-zone 3600
  assert_failure
  assert_output_contains "Zone must be a valid domain name"
}

@test "(dns:zones:ttl) updates existing zone TTL" {
  run dns_cmd zones:ttl example.com 1800
  assert_success

  run dns_cmd zones:ttl example.com 7200
  assert_success

  run dns_cmd zones:ttl example.com
  assert_success
  assert_output "7200"
}

# Per-domain TTL via apps:enable --ttl

@test "(dns:apps:enable --ttl) accepts valid TTL parameter" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 3600
  assert_success
  [[ "$output" == *"Enabled"* ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) accepts TTL with specific domains" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test1.example.com test2.example.com

  run dns_cmd apps:enable ttl-test-app test1.example.com --ttl 1800
  assert_success
  [[ "$output" == *"Enabled"* ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) validates TTL range" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 59
  assert_failure
  [[ "$output" == *"TTL must be 60-86400"* ]]

  run dns_cmd apps:enable ttl-test-app --ttl 86401
  assert_failure
  [[ "$output" == *"TTL must be 60-86400"* ]]

  cleanup_test_app ttl-test-app
}

# Helper function: get_zone_from_domain

@test "(get_zone_from_domain) extracts zone correctly" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain api.example.com"
  assert_success
  assert_output "example.com"

  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain www.api.example.com"
  assert_success
  assert_output "example.com"

  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain example.com"
  assert_success
  assert_output "example.com"
}

# Helper function: get_zone_ttl

@test "(get_zone_ttl) retrieves zone TTL when configured" {
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com:5400" >"$PLUGIN_DATA_ROOT/ZONE_TTLS"

  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_ttl example.com"
  assert_success
  assert_output "5400"
}

@test "(get_zone_ttl) returns error when zone TTL not configured" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_ttl example.com"
  assert_failure
}

# Helper function: get_domain_ttl

@test "(get_domain_ttl) retrieves domain-specific TTL" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  mkdir -p "$PLUGIN_DATA_ROOT/ttl-test-app"
  echo "test.example.com:7200" >"$PLUGIN_DATA_ROOT/ttl-test-app/DOMAIN_TTLS"

  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "7200"

  cleanup_test_app ttl-test-app
}

# TTL hierarchy: domain -> zone -> global -> default

@test "(get_domain_ttl) uses complete TTL hierarchy" {
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo "www.api.example.com:600" >"$PLUGIN_DATA_ROOT/test-app/DOMAIN_TTLS"
  echo "example.com:1800" >"$PLUGIN_DATA_ROOT/ZONE_TTLS"
  echo "3600" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # Domain-specific TTL (highest priority)
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app www.api.example.com"
  assert_success
  assert_output "600"

  # Zone TTL (middle priority)
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app other.example.com"
  assert_success
  assert_output "1800"

  # Global TTL (lower priority)
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app unknown.otherdomain.com"
  assert_success
  assert_output "3600"

  # Default TTL (lowest priority)
  rm -f "$PLUGIN_DATA_ROOT/GLOBAL_TTL"
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app unknown.otherdomain.com"
  assert_success
  assert_output "300"
}
