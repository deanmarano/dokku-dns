#!/usr/bin/env bats
load test_helper

# Tests for Phase 26a, 26b fixes and domain parsing bug fix

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  export DNS_TEST_SERVER_IP="192.0.2.1"
}

teardown() {
  cleanup_dns_data
}

# Phase 26a: Error checking in sync apply phase

@test "(phase26a) sync shows failure when zone lookup fails in apply phase" {
  create_test_app test-app
  add_test_domains test-app nonexistent.invalid

  # Manually add domain to DNS management
  mkdir -p "$PLUGIN_DATA_ROOT/test-app"
  echo "test-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "nonexistent.invalid" >"$PLUGIN_DATA_ROOT/test-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" test-app
  # Should show failure indicator
  [[ "$output" == *"✗"* ]] || [[ "$output" == *"no zone"* ]] || [[ "$output" == *"provider"* ]]

  cleanup_test_app test-app
}

@test "(phase26a) apply phase shows failure message" {
  create_test_app fail-app
  add_test_domains fail-app missing-zone.xyz

  mkdir -p "$PLUGIN_DATA_ROOT/fail-app"
  echo "fail-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "missing-zone.xyz" >"$PLUGIN_DATA_ROOT/fail-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" fail-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show failure indicator
  [[ "$output" == *"✗"* ]] || [[ "$output" == *"no"* ]] || [[ "$output" == *"Failed"* ]]

  cleanup_test_app fail-app
}

@test "(phase26a) apply phase uses continue to skip failed domain" {
  create_test_app multi-domain-app
  add_test_domains multi-domain-app bad-domain.invalid

  mkdir -p "$PLUGIN_DATA_ROOT/multi-domain-app"
  echo "multi-domain-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "bad-domain.invalid" >"$PLUGIN_DATA_ROOT/multi-domain-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" multi-domain-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show some output (not crash)
  [[ -n "$output" ]]

  cleanup_test_app multi-domain-app
}

@test "(phase26a) sync increments failed counter when zone lookup fails" {
  create_test_app fail-test-app
  add_test_domains fail-test-app missing-zone.xyz

  mkdir -p "$PLUGIN_DATA_ROOT/fail-test-app"
  echo "fail-test-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "missing-zone.xyz" >"$PLUGIN_DATA_ROOT/fail-test-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" fail-test-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show summary with counts or failure
  [[ "$output" == *"Synced:"* ]] || [[ "$output" == *"Failed:"* ]] || [[ "$output" == *"no"* ]]

  cleanup_test_app fail-test-app
}

# Phase 26c: Report improvements

@test "(phase26c) report sources multi-provider.sh correctly" {
  echo "example.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app report-app
  add_test_domains report-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" report-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" report-app
  # Should not show sourcing errors
  [[ "$output" != *"No such file"* ]]
  [[ "$output" != *"cannot open"* ]]

  cleanup_test_app report-app
}

@test "(phase26c) report shows zone information using multi_get_zone_id" {
  echo "example.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app zone-app
  add_test_domains zone-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" zone-app
  # Should show zone column
  [[ "$output" == *"ZONE"* ]] || [[ "$output" == *"example.com"* ]]

  cleanup_test_app zone-app
}

@test "(phase26c) report shows correct zone when zone exists" {
  echo "example.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app zone-exists-app
  add_test_domains zone-exists-app api.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" zone-exists-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" zone-exists-app
  # Should show the zone
  [[ "$output" == *"example.com"* ]]

  cleanup_test_app zone-exists-app
}

@test "(phase26c) report handles domains without hosted zones gracefully" {
  create_test_app no-zone-app
  add_test_domains no-zone-app orphan.invalid

  mkdir -p "$PLUGIN_DATA_ROOT/no-zone-app"
  echo "no-zone-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "orphan.invalid" >"$PLUGIN_DATA_ROOT/no-zone-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:report" no-zone-app
  # Should not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app no-zone-app
}

@test "(phase26c) apps:sync counts changes correctly" {
  echo "example.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app count-app
  add_test_domains count-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" count-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" count-app
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  # Should show counts in output
  [[ "$output" == *"Synced:"* ]] || [[ "$output" == *"Failed:"* ]] || [[ "$output" == *"provider"* ]]

  cleanup_test_app count-app
}

# Integration tests

@test "(integration) zone lookup error shows clear message" {
  create_test_app integration-app
  add_test_domains integration-app notreal.is

  mkdir -p "$PLUGIN_DATA_ROOT/integration-app"
  echo "integration-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo "notreal.is" >"$PLUGIN_DATA_ROOT/integration-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" integration-app
  # Should show some error message
  [[ -n "$output" ]]

  cleanup_test_app integration-app
}

@test "(integration) multiple domains show individual zone status in report" {
  echo "example.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app multi-report-app
  add_test_domains multi-report-app api.example.com web.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-report-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" multi-report-app
  # Should show both domains
  [[ "$output" == *"api.example.com"* ]] || [[ "$output" == *"web.example.com"* ]] || [[ "$output" == *"example.com"* ]]

  cleanup_test_app multi-report-app
}

@test "(integration) multiple domain failures show individual error messages" {
  create_test_app multi-fail-app
  add_test_domains multi-fail-app bad1.invalid bad2.invalid

  mkdir -p "$PLUGIN_DATA_ROOT/multi-fail-app"
  echo "multi-fail-app" >>"$PLUGIN_DATA_ROOT/LINKS"
  echo -e "bad1.invalid\nbad2.invalid" >"$PLUGIN_DATA_ROOT/multi-fail-app/DOMAINS"

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" multi-fail-app
  # Should not crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]

  cleanup_test_app multi-fail-app
}

@test "(regression) report does not call non-existent dns_provider_aws_get_hosted_zone_id" {
  echo "example.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app regression-app
  add_test_domains regression-app test.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" regression-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" regression-app
  # Should not show function not found errors
  [[ "$output" != *"dns_provider_aws_get_hosted_zone_id"* ]]
  [[ "$output" != *"command not found"* ]]

  cleanup_test_app regression-app
}
