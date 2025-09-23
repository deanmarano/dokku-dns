#!/usr/bin/env bats

load test_helper

setup() {
  # Skip setup in Docker environment - apps and provider already configured
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    setup_dns_provider aws
    # Export PLUGIN_DATA_ROOT so it's available to subshells
    export PLUGIN_DATA_ROOT
  fi
}

teardown() {
  # Clean up TTL configuration and DNS data
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi
}

@test "(dns:zones:ttl) sets zone TTL with valid input" {
  run dns_cmd zones:ttl example.com 3600
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 3600 seconds"

  # Verify TTL was stored
  run dns_cmd zones:ttl example.com
  assert_success
  assert_output "3600"
}

@test "(dns:zones:ttl) gets zone TTL when configured" {
  # Manually create ZONE_TTLS file
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com:7200" > "$PLUGIN_DATA_ROOT/ZONE_TTLS"

  run dns_cmd zones:ttl example.com
  assert_success
  assert_output "7200"
}

@test "(dns:zones:ttl) fails when no TTL configured for zone" {
  run dns_cmd zones:ttl example.com
  assert_failure
  assert_output_contains "No TTL configured for zone: example.com"
}

@test "(dns:zones:ttl) validates TTL minimum value" {
  run dns_cmd zones:ttl example.com 59
  assert_failure
  assert_output_contains "TTL value must be at least 60 seconds"
}

@test "(dns:zones:ttl) validates TTL maximum value" {
  run dns_cmd zones:ttl example.com 86401
  assert_failure
  assert_output_contains "TTL value must be no more than 86400 seconds"
}

@test "(dns:zones:ttl) validates TTL numeric format" {
  run dns_cmd zones:ttl example.com abc
  assert_failure
  assert_output_contains "TTL value must be a positive integer"
}

@test "(dns:zones:ttl) validates zone format" {
  run dns_cmd zones:ttl invalid-zone 3600
  assert_failure
  assert_output_contains "Zone must be a valid domain name"
}

@test "(dns:zones:ttl) requires zone parameter" {
  run dns_cmd zones:ttl
  assert_failure
  assert_output_contains "Please specify a zone name"
}

@test "(dns:zones:ttl) accepts minimum valid TTL (60)" {
  run dns_cmd zones:ttl example.com 60
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 60 seconds"
}

@test "(dns:zones:ttl) accepts maximum valid TTL (86400)" {
  run dns_cmd zones:ttl example.com 86400
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 86400 seconds"
}

@test "(dns:zones:ttl) updates existing zone TTL" {
  # Set initial TTL
  run dns_cmd zones:ttl example.com 1800
  assert_success

  # Update TTL
  run dns_cmd zones:ttl example.com 7200
  assert_success
  assert_output_contains "Zone TTL set for 'example.com' to 7200 seconds"

  # Verify updated TTL
  run dns_cmd zones:ttl example.com
  assert_success
  assert_output "7200"
}

@test "(get_zone_from_domain) extracts zone from subdomain" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain api.example.com"
  assert_success
  assert_output "example.com"
}

@test "(get_zone_from_domain) extracts zone from nested subdomain" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain www.api.example.com"
  assert_success
  assert_output "example.com"
}

@test "(get_zone_from_domain) handles root domain" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain example.com"
  assert_success
  assert_output "example.com"
}

@test "(get_zone_from_domain) handles complex TLD" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_from_domain api.example.co.uk"
  assert_success
  assert_output "co.uk"
}

@test "(get_zone_ttl) retrieves zone TTL when configured" {
  # Set up zone TTL
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com:5400" > "$PLUGIN_DATA_ROOT/ZONE_TTLS"

  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_ttl example.com"
  assert_success
  assert_output "5400"
}

@test "(get_zone_ttl) returns error when zone TTL not configured" {
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_zone_ttl example.com"
  assert_failure
}

@test "(get_domain_ttl) uses zone TTL when domain TTL not configured" {
  # Set up app and zone TTL
  create_test_app zone-ttl-test-app
  add_test_domains zone-ttl-test-app api.example.com

  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com:4800" > "$PLUGIN_DATA_ROOT/ZONE_TTLS"

  # Test get_domain_ttl falls back to zone TTL
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl zone-ttl-test-app api.example.com"
  assert_success
  assert_output "4800"

  cleanup_test_app zone-ttl-test-app
}

@test "(get_domain_ttl) prioritizes domain TTL over zone TTL" {
  # Set up app with both domain and zone TTL
  create_test_app zone-ttl-test-app
  add_test_domains zone-ttl-test-app api.example.com

  # Set domain-specific TTL
  mkdir -p "$PLUGIN_DATA_ROOT/zone-ttl-test-app"
  echo "api.example.com:1200" > "$PLUGIN_DATA_ROOT/zone-ttl-test-app/DOMAIN_TTLS"

  # Set zone TTL
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com:4800" > "$PLUGIN_DATA_ROOT/ZONE_TTLS"

  # Test get_domain_ttl prioritizes domain TTL
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl zone-ttl-test-app api.example.com"
  assert_success
  assert_output "1200"

  cleanup_test_app zone-ttl-test-app
}

@test "(get_domain_ttl) falls back to global TTL when no zone TTL" {
  # Set global TTL only
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "2400" > "$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # Ensure no zone TTL exists
  rm -f "$PLUGIN_DATA_ROOT/ZONE_TTLS" 2>/dev/null || true

  # Test get_domain_ttl function falls back to global TTL
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app api.example.com"
  assert_success
  assert_output "2400"
}

@test "(get_domain_ttl) uses complete TTL hierarchy" {
  # Test the complete TTL hierarchy: domain -> zone -> global -> default
  # Set up TTL hierarchy
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo "www.api.example.com:600" > "$PLUGIN_DATA_ROOT/test-app/DOMAIN_TTLS"  # Domain-specific

  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com:1800" > "$PLUGIN_DATA_ROOT/ZONE_TTLS"                    # Zone TTL
  echo "3600" > "$PLUGIN_DATA_ROOT/GLOBAL_TTL"                               # Global TTL

  # Test domain-specific TTL (highest priority)
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app www.api.example.com"
  assert_success
  assert_output "600"

  # Test zone TTL (middle priority)
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app other.example.com"
  assert_success
  assert_output "1800"

  # Test global TTL (lower priority)
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app unknown.otherdomain.com"
  assert_success
  assert_output "3600"

  # Test default TTL (lowest priority)
  rm -f "$PLUGIN_DATA_ROOT/GLOBAL_TTL"
  run bash -c "DNS_ROOT='$PLUGIN_DATA_ROOT' source config && source functions && get_domain_ttl test-app unknown.otherdomain.com"
  assert_success
  assert_output "300"
}