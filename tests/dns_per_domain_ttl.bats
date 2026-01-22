#!/usr/bin/env bats

load test_helper

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
}

teardown() {
  cleanup_dns_data
}

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

@test "(dns:apps:enable --ttl) validates TTL minimum value" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 59
  assert_failure
  [[ "$output" == *"TTL must be 60-86400"* ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) validates TTL maximum value" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 86401
  assert_failure
  [[ "$output" == *"TTL must be 60-86400"* ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) validates TTL numeric format" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl abc
  assert_failure
  [[ "$output" == *"TTL must be 60-86400"* ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) accepts minimum valid TTL (60)" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 60
  assert_success
  [[ "$output" == *"Enabled"* ]]

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) accepts maximum valid TTL (86400)" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  run dns_cmd apps:enable ttl-test-app --ttl 86400
  assert_success
  [[ "$output" == *"Enabled"* ]]

  cleanup_test_app ttl-test-app
}

@test "(get_domain_ttl) retrieves domain-specific TTL when configured" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  mkdir -p "$PLUGIN_DATA_ROOT/ttl-test-app"
  echo "test.example.com:7200" >"$PLUGIN_DATA_ROOT/ttl-test-app/DOMAIN_TTLS"

  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "7200"

  cleanup_test_app ttl-test-app
}

@test "(get_domain_ttl) falls back to global TTL when domain TTL not configured" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "1800" >"$PLUGIN_DATA_ROOT/GLOBAL_TTL"

  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "1800"

  cleanup_test_app ttl-test-app
}

@test "(get_domain_ttl) falls back to default TTL when no TTL configured" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test.example.com

  rm -f "$PLUGIN_DATA_ROOT/GLOBAL_TTL" 2>/dev/null || true
  rm -f "$PLUGIN_DATA_ROOT/ttl-test-app/DOMAIN_TTLS" 2>/dev/null || true

  run bash -c "source functions && get_domain_ttl ttl-test-app test.example.com"
  assert_success
  assert_output "300"

  cleanup_test_app ttl-test-app
}

@test "(dns:apps:enable --ttl) works with multiple domains and same TTL" {
  create_test_app ttl-test-app
  add_test_domains ttl-test-app test1.example.com test2.example.com test3.example.com

  run dns_cmd apps:enable ttl-test-app test1.example.com test2.example.com --ttl 900
  assert_success
  [[ "$output" == *"Enabled"* ]]

  cleanup_test_app ttl-test-app
}
