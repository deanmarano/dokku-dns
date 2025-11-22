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

@test "(dns:apps:enable --ttl) accepts valid TTL parameter" {
  # Create test app and enable DNS management with custom TTL
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 3600
  # Command may exit with 1 due to no hosted zones, but should show TTL in output
  assert_output_contains "Adding all domains for app 'ttl-test-app' with TTL 3600 seconds"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) accepts TTL with specific domains" {
  # Create test app and enable DNS management with custom TTL for specific domains
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test1.example.com test2.example.com

  run dns_cmd apps:enable ttl-test-app test1.example.com --ttl 1800
  # Command may exit with 1 due to no hosted zones, but should show TTL in output
  assert_output_contains "Adding specified domains for app 'ttl-test-app' with TTL 1800 seconds"
  # Note: Reduced from 7 to 3 due to verbose logging being conditional (DNS_VERBOSE)
  assert_output_contains "test1.example.com" 3

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) validates TTL minimum value" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 59
  assert_failure
  assert_output_contains "TTL value must be at least 60 seconds"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) validates TTL maximum value" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 86401
  assert_failure
  assert_output_contains "TTL value must be no more than 86400 seconds"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) validates TTL numeric format" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl abc
  assert_failure
  assert_output_contains "TTL value must be a positive integer"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) accepts minimum valid TTL (60)" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 60
  # Command may exit with 1 due to no hosted zones, but should show TTL in output
  assert_output_contains "Adding all domains for app 'ttl-test-app' with TTL 60 seconds"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) accepts maximum valid TTL (86400)" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 86400
  # Command may exit with 1 due to no hosted zones, but should show TTL in output
  assert_output_contains "Adding all domains for app 'ttl-test-app' with TTL 86400 seconds"

  cleanup_test_app ttl-test-app
}

@test "(get_domain_ttl) retrieves domain-specific TTL when configured" {
  # Set up app with domain-specific TTL
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  # Manually create DOMAIN_TTLS file
  mkdir -p "$PLUGIN_DATA_ROOT/ttl-test-app"
  echo "test.example.com:7200" >"$PLUGIN_DATA_ROOT/ttl-test-app/DOMAIN_TTLS"

  # Test get_domain_ttl function (source functions first)
  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "7200"

  cleanup_test_app ttl-test-app
}

@test "(get_domain_ttl) falls back to global TTL when domain TTL not configured" {
  # Set up app without domain-specific TTL
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  # Set global TTL
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "1800" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  # Test get_domain_ttl function falls back to global TTL
  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "1800"

  cleanup_test_app ttl-test-app
}

@test "(get_domain_ttl) falls back to default TTL when no TTL configured" {
  # Set up app without any TTL configuration
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  # Ensure no TTL files exist
  rm -f "$PLUGIN_DATA_ROOT/GLOBAL_TTL" 2>/dev/null || true
  rm -f "$PLUGIN_DATA_ROOT/ttl-test-app/DOMAIN_TTLS" 2>/dev/null || true

  # Test get_domain_ttl function falls back to default
  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "300"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) works with multiple domains and same TTL" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test1.example.com test2.example.com test3.example.com

  run dns_cmd apps:enable ttl-test-app test1.example.com test2.example.com --ttl 900
  # Command may exit with 1 due to no hosted zones, but should show TTL in output
  assert_output_contains "Adding specified domains for app 'ttl-test-app' with TTL 900 seconds"
  # Note: Reduced from 7 to 3 due to verbose logging being conditional (DNS_VERBOSE)
  assert_output_contains "test1.example.com" 3
  assert_output_contains "test2.example.com" 3

  cleanup_test_app ttl-test-app
}
