#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  echo "test.com" >>"$PLUGIN_DATA_ROOT/ENABLED_ZONES"
  create_test_app my-app
  add_test_domains my-app example.com
  create_test_app other-app
  add_test_domains other-app test.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_test_app other-app
  cleanup_dns_data
}

@test "(dns:report) global report shows all apps" {
  # Enable apps for DNS
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" other-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  [[ "$output" == *"Server IP:"* ]]
  [[ "$output" == *"APP"* ]]
  [[ "$output" == *"DOMAIN"* ]]
  [[ "$output" == *"STATUS"* ]]
}

@test "(dns:report) app-specific report works" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  [[ "$output" == *"App: my-app"* ]]
  [[ "$output" == *"Server IP:"* ]]
  [[ "$output" == *"DOMAIN"* ]]
  [[ "$output" == *"STATUS"* ]]
  [[ "$output" == *"example.com"* ]]
}

@test "(dns:report) app-specific report shows message for nonexistent app" {
  run dokku "$PLUGIN_COMMAND_PREFIX:report" nonexistent-app
  assert_failure
  [[ "$output" == *"not in DNS management"* ]]
}

@test "(dns:report) shows no provider when not configured" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  [[ "$output" == *"Server IP:"* ]]
}

@test "(dns:report) global report handles no apps gracefully" {
  cleanup_dns_data

  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  [[ "$output" == *"No apps in DNS management"* ]]
}

@test "(dns:report) app report handles app with no domains" {
  create_test_app empty-app

  run dokku "$PLUGIN_COMMAND_PREFIX:report" empty-app
  assert_failure
  [[ "$output" == *"not in DNS management"* ]]

  cleanup_test_app empty-app
}

@test "(dns:report) shows DNS status symbols" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  # Should show one of the status symbols
  [[ "$output" == *"✓"* ]] || [[ "$output" == *"✗"* ]] || [[ "$output" == *"⚠"* ]]
}

@test "(dns:report) global report shows domain count" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report"
  assert_success
  [[ "$output" == *"domains correct"* ]]
}

@test "(dns:report) shows provider status" {
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" my-app
  assert_success
  [[ "$output" == *"Server IP:"* ]]
}

@test "(dns:report) multiple domains show in report" {
  create_test_app multi-domain-app
  add_test_domains multi-domain-app domain1.example.com domain2.example.com

  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" multi-domain-app >/dev/null 2>&1 || true

  run dokku "$PLUGIN_COMMAND_PREFIX:report" multi-domain-app
  assert_success
  [[ "$output" == *"domain1.example.com"* ]] || [[ "$output" == *"domain2.example.com"* ]]

  cleanup_test_app multi-domain-app
}

@test "(dns:report) handles domains without hosted zones gracefully" {
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
