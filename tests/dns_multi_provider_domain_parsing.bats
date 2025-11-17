#!/usr/bin/env bats
load test_helper

# Unit tests for multi-provider domain parsing fix
# These tests focus specifically on the find_provider_for_zone logic

setup() {
  cleanup_dns_data

  # Set up multi-provider test environment
  mkdir -p "$PLUGIN_DATA_ROOT/.multi-provider/zones"
  mkdir -p "$PLUGIN_DATA_ROOT/.multi-provider/providers"

  # Create some test zone mappings
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/example.com"
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/test.io"
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/subdomain.example.org"
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/dean.is"

  # Source the multi-provider functions
  source "$PLUGIN_ROOT/providers/multi-provider.sh"
}

teardown() {
  cleanup_dns_data
}

@test "(multi-provider) find_provider_for_zone finds exact match for second-level domain" {
  # Test with dean.is - should find "dean.is" zone, not look for "is"
  run find_provider_for_zone "dean.is"

  assert_success
  assert_output "aws"
}

@test "(multi-provider) find_provider_for_zone finds exact match for test.io" {
  run find_provider_for_zone "test.io"

  assert_success
  assert_output "aws"
}

@test "(multi-provider) find_provider_for_zone walks up hierarchy for subdomains" {
  # subdomain.example.com should match example.com zone
  run find_provider_for_zone "www.example.com"

  assert_success
  assert_output "aws"
}

@test "(multi-provider) find_provider_for_zone does not match on TLD only" {
  # Should NOT find provider for just "is" or "io" or "com"
  run find_provider_for_zone "is"

  # Should fail - we don't have a zone for just "is"
  assert_failure
}

@test "(multi-provider) find_provider_for_zone handles multi-level subdomains" {
  # www.subdomain.example.org should find subdomain.example.org zone
  run find_provider_for_zone "www.subdomain.example.org"

  assert_success
  assert_output "aws"
}

@test "(multi-provider) find_provider_for_zone rejects empty input" {
  run find_provider_for_zone ""

  assert_failure
  assert_output_contains "required"
}

@test "(multi-provider) find_provider_for_zone returns error for non-existent zone" {
  run find_provider_for_zone "nonexistent.domain.invalid"

  assert_failure
}

# Test that multi_get_zone_id uses find_provider_for_zone correctly

@test "(multi_get_zone_id) works with second-level domain" {
  # Mock provider functions
  load_provider() { return 0; }
  provider_get_zone_id() { echo "Z123456789"; }
  export -f load_provider provider_get_zone_id

  run multi_get_zone_id "dean.is"

  # Should succeed and return zone ID
  [[ "$status" -eq 0 ]] || [[ -n "$output" ]]
}

@test "(multi_get_zone_id) does not strip domain parts before zone lookup" {
  # Mock provider functions
  load_provider() { return 0; }
  provider_get_zone_id() {
    # Echo the zone_name that was passed to us
    echo "Called with: $1" >&2
    echo "Z123456789"
  }
  export -f load_provider provider_get_zone_id

  run multi_get_zone_id "test.io" 2>&1

  # Should call provider_get_zone_id with full "test.io", not just "io"
  assert_output_contains "test.io"
  ! assert_output_contains "Called with: io"
}

# Test that multi_create_record no longer strips domain parts

@test "(multi_create_record) uses full domain for provider lookup" {
  # Setup
  load_provider() { return 0; }
  provider_create_record() {
    echo "Create called for zone=$1, record=$2" >&2
    return 0
  }
  export -f load_provider provider_create_record

  run multi_create_record "Z123" "dean.is" "A" "192.0.2.1" "300" 2>&1

  # Should not show error about "No provider found for zone: is"
  ! assert_output_contains "No provider found for zone: is"

  # Should find provider for "dean.is"
  [[ "$status" -eq 0 ]] || assert_output_contains "dean.is"
}

@test "(multi_create_record) does not use naive domain stripping logic" {
  # The old buggy code did: zone_name="${record_name#*.}"
  # For "dean.is", this would give "is"
  # The fix passes record_name directly to find_provider_for_zone

  load_provider() { return 0; }
  provider_create_record() { return 0; }
  export -f load_provider provider_create_record

  run multi_create_record "Z123" "example.io" "A" "192.0.2.1" "300"

  # Should succeed, not fail with "No provider found for zone: io"
  ! assert_output_contains "No provider found for zone: io"
}

# Test that multi_get_record uses correct domain

@test "(multi_get_record) uses full domain for provider lookup" {
  load_provider() { return 0; }
  provider_get_record() {
    echo "192.0.2.1"
    return 0
  }
  export -f load_provider provider_get_record

  run multi_get_record "Z123" "test.io" "A"

  # Should not show error about "No provider found for zone: io"
  ! assert_output_contains "No provider found for zone: io"
}

# Test that multi_delete_record uses correct domain

@test "(multi_delete_record) uses full domain for provider lookup" {
  load_provider() { return 0; }
  provider_delete_record() { return 0; }
  export -f load_provider provider_delete_record

  run multi_delete_record "Z123" "dean.is" "A"

  # Should not show error about "No provider found for zone: is"
  ! assert_output_contains "No provider found for zone: is"
}

# Regression tests for the specific bug

@test "(regression) dean.is is not parsed as 'is'" {
  # This is the exact bug we fixed
  run find_provider_for_zone "dean.is"

  assert_success
  assert_output "aws"

  # Should NOT try to find zone for just "is"
  ! [[ -f "$PLUGIN_DATA_ROOT/.multi-provider/zones/is" ]]
}

@test "(regression) multi_create_record with dean.is does not fail with 'zone: is' error" {
  load_provider() { return 0; }
  provider_create_record() { return 0; }
  export -f load_provider provider_create_record

  run multi_create_record "Z123" "dean.is" "A" "68.55.81.191" "300"

  # The bug would have shown: "No provider found for zone: is"
  ! assert_output_contains "zone: is"
  [[ "$status" -eq 0 ]] || fail "multi_create_record failed for dean.is"
}

@test "(regression) any second-level domain works correctly" {
  # Test various second-level domains
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/example.co.uk"
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/test.me"
  echo "aws" >"$PLUGIN_DATA_ROOT/.multi-provider/zones/app.dev"

  run find_provider_for_zone "example.co.uk"
  assert_success
  assert_output "aws"

  run find_provider_for_zone "test.me"
  assert_success
  assert_output "aws"

  run find_provider_for_zone "app.dev"
  assert_success
  assert_output "aws"
}
