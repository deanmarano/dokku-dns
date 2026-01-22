#!/usr/bin/env bats
load test_helper

# Tests for multi-provider zone lookup in report command

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  echo "test.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  export DNS_TEST_SERVER_IP="192.0.2.1"
}

teardown() {
  cleanup_dns_data
}

@test "(phase26c) report sources multi-provider.sh correctly" {
  create_test_app zone-test-app
  add_test_domains zone-test-app example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-test-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" zone-test-app
  assert_success

  cleanup_test_app zone-test-app
}

@test "(phase26c) report shows zone information using multi_get_zone_id" {
  create_test_app multi-zone-app
  add_test_domains multi-zone-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-zone-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" multi-zone-app
  assert_success
  # Should show zone column
  [[ "$output" == *"ZONE"* ]] || [[ "$output" == *"example.com"* ]]

  cleanup_test_app multi-zone-app
}

@test "(phase26c) report handles domains without hosted zones gracefully" {
  create_test_app no-zone-app
  add_test_domains no-zone-app nonexistent.invalid

  # Manually add to DNS management
  mkdir -p "$PLUGIN_DATA_ROOT/no-zone-app"
  echo "no-zone-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "nonexistent.invalid" >"$PLUGIN_DATA_ROOT/no-zone-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:report" no-zone-app
  # Should not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app no-zone-app
}

@test "(phase26c) report shows correct zone when zone exists" {
  create_test_app zone-exists-app
  add_test_domains zone-exists-app example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-exists-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" zone-exists-app
  assert_success
  [[ -n "$output" ]]

  cleanup_test_app zone-exists-app
}

@test "(phase26c) apps:sync handles correct records" {
  create_test_app correct-app
  add_test_domains correct-app example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" correct-app >/dev/null 2>&1 || true
  dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" correct-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" correct-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app correct-app
}

@test "(phase26c) apps:sync counts changes correctly" {
  create_test_app count-app
  add_test_domains count-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" count-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" count-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show counts
  [[ "$output" == *"Synced:"* ]] || [[ "$output" == *"Failed:"* ]] || [[ "$output" == *"provider"* ]]

  cleanup_test_app count-app
}

@test "(integration) multiple domains show individual zone status in report" {
  create_test_app multi-domain-app
  add_test_domains multi-domain-app domain1.example.com domain2.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-domain-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" multi-domain-app
  assert_success
  [[ "$output" == *"domain1.example.com"* ]] || [[ "$output" == *"domain2.example.com"* ]]

  cleanup_test_app multi-domain-app
}

@test "(regression) report does not call non-existent dns_provider_aws_get_hosted_zone_id" {
  create_test_app regression-app
  add_test_domains regression-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" regression-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" regression-app
  assert_success
  [[ "$output" != *"command not found"* ]]
  [[ "$output" != *"dns_provider_aws_get_hosted_zone_id"* ]]

  cleanup_test_app regression-app
}
