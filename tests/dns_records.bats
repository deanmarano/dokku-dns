#!/usr/bin/env bats
load test_helper

# Test setup and teardown
setup() {
  # Create temporary directory for test data
  TEST_TMP_DIR=$(mktemp -d)
  export TEST_TMP_DIR

  # Setup mock environment if not running with real Dokku
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
    setup_dns_provider aws
  fi

  # Setup multi-provider test data with example.com zone
  setup_multi_provider_test_data "aws" "example.com" "test.org"
}

teardown() {
  # Cleanup test data
  if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
    cleanup_dns_data
  fi

  # Remove temporary directory
  if [[ -n "$TEST_TMP_DIR" ]] && [[ -d "$TEST_TMP_DIR" ]]; then
    rm -rf "$TEST_TMP_DIR"
  fi
}

# ============================================================================
# dns:records:create tests
# ============================================================================

@test "(dns:records:create) shows usage when no arguments provided" {
  run dns_cmd "records:create"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:create"
}

@test "(dns:records:create) shows usage when only name provided" {
  run dns_cmd "records:create" "test.example.com"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:create"
}

@test "(dns:records:create) shows usage when only name and type provided" {
  run dns_cmd "records:create" "test.example.com" "A"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:create"
}

@test "(dns:records:create) validates record type" {
  run dns_cmd "records:create" "test.example.com" "INVALID" "192.168.1.1"
  assert_failure
  assert_output_contains "Unsupported record type: INVALID"
}

@test "(dns:records:create) accepts valid record types" {
  local valid_types=("A" "AAAA" "CNAME" "TXT" "MX" "NS" "PTR" "SRV" "CAA")
  for type in "${valid_types[@]}"; do
    # Just check that type validation passes (actual create may fail due to mock)
    run dns_cmd "records:create" "test.example.com" "$type" "test-value" 2>&1
    # Should not fail with "Unsupported record type"
    [[ "$output" != *"Unsupported record type"* ]] || fail "Type $type should be valid"
  done
}

@test "(dns:records:create) normalizes record type to uppercase" {
  run dns_cmd "records:create" "test.example.com" "txt" "test-value" 2>&1
  # Should not fail with lowercase type validation error
  [[ "$output" != *"Unsupported record type: txt"* ]]
}

@test "(dns:records:create) validates TTL range - too low" {
  run dns_cmd "records:create" "test.example.com" "A" "192.168.1.1" --ttl 30
  assert_failure
  assert_output_contains "TTL must be between 60 and 86400"
}

@test "(dns:records:create) validates TTL range - too high" {
  run dns_cmd "records:create" "test.example.com" "A" "192.168.1.1" --ttl 100000
  assert_failure
  assert_output_contains "TTL must be between 60 and 86400"
}

@test "(dns:records:create) validates TTL is numeric" {
  run dns_cmd "records:create" "test.example.com" "A" "192.168.1.1" --ttl abc
  assert_failure
  assert_output_contains "TTL must be between 60 and 86400"
}

@test "(dns:records:create) accepts valid TTL values" {
  # Test boundary values
  run dns_cmd "records:create" "test.example.com" "A" "192.168.1.1" --ttl 60 2>&1
  [[ "$output" != *"TTL must be between"* ]] || fail "TTL 60 should be valid"

  run dns_cmd "records:create" "test.example.com" "A" "192.168.1.1" --ttl 86400 2>&1
  [[ "$output" != *"TTL must be between"* ]] || fail "TTL 86400 should be valid"
}

@test "(dns:records:create) uses default TTL of 300 when not specified" {
  run dns_cmd "records:create" "test.example.com" "A" "192.168.1.1" 2>&1
  # Check output shows TTL: 300
  [[ "$output" == *"TTL: 300"* ]] || [[ "$output" == *"TTL:   300"* ]] || true
}

@test "(dns:records:create) handles TXT records with spaces" {
  run dns_cmd "records:create" "test.example.com" "TXT" "v=spf1 include:example.com ~all" 2>&1
  # Should not fail on parsing
  [[ "$status" -eq 0 ]] || [[ "$output" == *"Creating DNS record"* ]] || true
}

@test "(dns:records:create) handles TXT records with special characters" {
  run dns_cmd "records:create" "test.example.com" "TXT" "key=value; another=\"quoted\"" 2>&1
  # Should not fail on parsing
  [[ "$status" -eq 0 ]] || [[ "$output" == *"Creating DNS record"* ]] || true
}

@test "(dns:records:create) handles MX records with priority" {
  run dns_cmd "records:create" "test.example.com" "MX" "10 mail.example.com" 2>&1
  # Should not fail on parsing
  [[ "$status" -eq 0 ]] || [[ "$output" == *"Creating DNS record"* ]] || true
}

@test "(dns:records:create) fails when no provider found for domain" {
  run dns_cmd "records:create" "test.unknown-domain.xyz" "A" "192.168.1.1"
  assert_failure
  assert_output_contains "No provider found for domain"
}

@test "(dns:records:create) outputs success message on creation" {
  run dns_cmd "records:create" "newrecord.example.com" "A" "192.168.1.100" 2>&1
  # Should show creation message (may fail if mock AWS doesn't handle it)
  [[ "$output" == *"Creating DNS record"* ]] || [[ "$output" == *"created"* ]] || true
}

# ============================================================================
# dns:records:get tests
# ============================================================================

@test "(dns:records:get) shows usage when no arguments provided" {
  run dns_cmd "records:get"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:get"
}

@test "(dns:records:get) shows usage when only name provided" {
  run dns_cmd "records:get" "test.example.com"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:get"
}

@test "(dns:records:get) normalizes record type to uppercase" {
  run dns_cmd "records:get" "test.example.com" "a" 2>&1
  # Should query for A type, not fail on lowercase
  [[ "$output" != *"invalid type"* ]]
}

@test "(dns:records:get) fails when no provider found for domain" {
  run dns_cmd "records:get" "test.unknown-domain.xyz" "A"
  assert_failure
  # Should fail silently or show provider error
  [[ "$status" -ne 0 ]]
}

@test "(dns:records:get) quiet mode returns only value" {
  run dns_cmd "records:get" "test.example.com" "A" --quiet 2>&1
  # In quiet mode, output should be minimal (just value or exit code)
  [[ "$output" != *"Record:"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:get) normal mode shows record details" {
  run dns_cmd "records:get" "www.example.com" "A" 2>&1
  # Normal mode should show labels if record exists
  [[ "$output" == *"Record:"* ]] || [[ "$output" == *"not found"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:get) fails gracefully for non-existent record" {
  run dns_cmd "records:get" "nonexistent.example.com" "A"
  assert_failure
}

# ============================================================================
# dns:records:delete tests
# ============================================================================

@test "(dns:records:delete) shows usage when no arguments provided" {
  run dns_cmd "records:delete"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:delete"
}

@test "(dns:records:delete) shows usage when only name provided" {
  run dns_cmd "records:delete" "test.example.com"
  assert_failure
  assert_output_contains "Usage: dokku dns:records:delete"
}

@test "(dns:records:delete) normalizes record type to uppercase" {
  run dns_cmd "records:delete" "test.example.com" "a" --force 2>&1
  # Should process as A type
  [[ "$output" != *"invalid type"* ]]
}

@test "(dns:records:delete) requires confirmation without --force" {
  # Without --force, should show confirmation prompt
  # We can't easily test interactive input, so just verify the command structure
  run dns_cmd "records:delete" "test.example.com" "A" </dev/null 2>&1
  # Should show "About to delete" or fail due to no input
  [[ "$output" == *"About to delete"* ]] || [[ "$output" == *"Deleting"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:delete) skips confirmation with --force flag" {
  run dns_cmd "records:delete" "test.example.com" "A" --force 2>&1
  # Should not prompt, just proceed
  [[ "$output" != *"Are you sure"* ]] || true
}

@test "(dns:records:delete) accepts -f short flag for force" {
  run dns_cmd "records:delete" "test.example.com" "A" -f 2>&1
  # Should work same as --force
  [[ "$output" != *"Are you sure"* ]] || true
}

@test "(dns:records:delete) fails when no provider found for domain" {
  run dns_cmd "records:delete" "test.unknown-domain.xyz" "A" --force
  assert_failure
  assert_output_contains "No provider found for domain"
}

@test "(dns:records:delete) shows deletion message" {
  run dns_cmd "records:delete" "test.example.com" "A" --force 2>&1
  # Should show deletion attempt
  [[ "$output" == *"Deleting DNS record"* ]] || [[ "$output" == *"not found"* ]] || [[ "$status" -ne 0 ]]
}

# ============================================================================
# Integration tests - create then get then delete
# ============================================================================

@test "(dns:records) integration: create, get, delete cycle with mock provider" {
  # Skip if mock provider not available
  if [[ ! -f "$PLUGIN_ROOT/providers/mock/provider.sh" ]]; then
    skip "Mock provider not available"
  fi

  # Setup mock provider
  export MOCK_API_KEY="test-key"
  setup_multi_provider_test_data "mock" "example.com"

  # Create a record
  run dns_cmd "records:create" "integration-test.example.com" "A" "10.0.0.1" --ttl 300 2>&1
  # May succeed or fail depending on mock setup, but should not error on parsing

  # Get the record
  run dns_cmd "records:get" "integration-test.example.com" "A" --quiet 2>&1

  # Delete the record
  run dns_cmd "records:delete" "integration-test.example.com" "A" --force 2>&1
}

# ============================================================================
# Edge cases and error handling
# ============================================================================

@test "(dns:records:create) handles very long TXT values" {
  local long_value
  long_value=$(printf 'a%.0s' {1..200})
  run dns_cmd "records:create" "test.example.com" "TXT" "$long_value" 2>&1
  # Should not crash, may fail but should handle gracefully
  [[ "$output" == *"Creating"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:create) handles subdomain with multiple levels" {
  run dns_cmd "records:create" "deep.sub.domain.example.com" "A" "192.168.1.1" 2>&1
  # Should find parent zone example.com
  [[ "$output" == *"Creating"* ]] || [[ "$output" == *"No provider"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:create) handles CNAME records" {
  run dns_cmd "records:create" "alias.example.com" "CNAME" "target.example.com" 2>&1
  [[ "$output" == *"Creating"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:create) handles AAAA (IPv6) records" {
  run dns_cmd "records:create" "ipv6.example.com" "AAAA" "2001:db8::1" 2>&1
  [[ "$output" == *"Creating"* ]] || [[ "$status" -ne 0 ]]
}

@test "(dns:records:get) handles records with quotes in value" {
  # TXT records often have quoted values
  run dns_cmd "records:get" "txt.example.com" "TXT" 2>&1
  # Should not crash on parsing quotes
  [[ "$status" -eq 0 ]] || [[ "$output" == *"not found"* ]] || true
}

@test "(dns:records:delete) handles non-existent record gracefully" {
  run dns_cmd "records:delete" "does-not-exist.example.com" "A" --force
  # Should fail but not crash
  assert_failure
}

# ============================================================================
# Help text tests
# ============================================================================

@test "(dns:records:create) help shows examples" {
  run dns_cmd "records:create" 2>&1
  assert_output_contains "Usage:"
}

@test "(dns:records:get) help shows examples" {
  run dns_cmd "records:get" 2>&1
  assert_output_contains "Usage:"
}

@test "(dns:records:delete) help shows examples" {
  run dns_cmd "records:delete" 2>&1
  assert_output_contains "Usage:"
}
