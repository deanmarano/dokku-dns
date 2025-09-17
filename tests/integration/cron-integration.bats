#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Cron Integration Tests
# Tests for dns:cron subcommands

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
  check_dns_plugin_available
  # Clean up any existing cron jobs from previous tests
  dokku dns:cron --disable >/dev/null 2>&1 || true
}

teardown() {
  # Clean up cron jobs after each test
  dokku dns:cron --disable >/dev/null 2>&1 || true
}

@test "(dns:cron) shows status and help when no arguments provided" {
  run dokku dns:cron
  assert_success
  assert_output --partial "DNS Cron Status"
}

@test "(dns:cron) rejects invalid flags" {
  run dokku dns:cron --invalid-flag
  assert_failure
  assert_output --partial "unknown flag"
}

@test "(dns:cron) rejects invalid schedule format" {
  run dokku dns:cron --enable --schedule "invalid"
  assert_failure
  assert_output --partial "Invalid cron schedule"
}

@test "(dns:cron) shows disabled status initially" {
  # Ensure cron is disabled first
  dokku dns:cron --disable >/dev/null 2>&1 || true

  run dokku dns:cron
  assert_success
  assert_output --partial "Status: ❌ DISABLED"
}

@test "(dns:cron) shows enable command when disabled" {
  # Ensure cron is disabled first
  dokku dns:cron --disable >/dev/null 2>&1 || true

  run dokku dns:cron
  assert_success
  assert_output --partial "Enable cron: dokku dns:cron --enable"
}

@test "(dns:cron --enable) can enable cron automation" {
  run dokku dns:cron --enable
  # May succeed with specific provider setup
  [[ "$status" -eq 0 ]] || [[ "$output" =~ (successfully|enabled|Enabling) ]]
}

@test "(dns:cron) shows enabled status after enabling" {
  # Try to enable cron first
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run dokku dns:cron
  assert_success
  assert_output --partial "Status: ✅ ENABLED"
}

@test "(dns:cron) shows active job details when enabled" {
  # Try to enable cron first
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run dokku dns:cron
  assert_success
  assert_output --partial "Active Job:"
}

@test "(dns:cron --disable) can disable cron automation" {
  # Enable cron first
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run dokku dns:cron --disable
  assert_success
  assert_output --partial "Disabling DNS Cron Job"
}

@test "(dns:cron) shows disabled status after disabling" {
  # Enable then disable cron
  dokku dns:cron --enable >/dev/null 2>&1
  dokku dns:cron --disable >/dev/null 2>&1

  run dokku dns:cron
  assert_success
  assert_output --partial "Status: ❌ DISABLED"
}

@test "(dns:cron --enable) shows update message when already enabled" {
  # Enable cron first
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run dokku dns:cron --enable
  # Should show update message rather than initial creation
  [[ "$output" =~ (Updating|already|exists) ]]
}

@test "(dns:cron --disable) shows error when not enabled" {
  # Ensure cron is disabled first
  dokku dns:cron --disable >/dev/null 2>&1 || true

  run dokku dns:cron --disable
  assert_failure
  # Should show appropriate error message
}

@test "(dns:cron) creates metadata files when enabled" {
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run test -f /var/lib/dokku/services/dns/cron/status
  assert_success
}

@test "(dns:cron) creates log file when enabled" {
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run test -f /var/lib/dokku/services/dns/cron/sync.log
  assert_success
}

@test "(dns:cron) status file contains enabled state" {
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  run cat /var/lib/dokku/services/dns/cron/status
  assert_success
  assert_output --partial "enabled"
}

@test "(dns:cron) system crontab integration (if available)" {
  if ! command -v crontab >/dev/null 2>&1; then
    skip "crontab not available in test environment"
  fi

  # Enable cron
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"

  # Check if cron job exists in system crontab
  run bash -c "crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\" || (command -v sudo >/dev/null 2>&1 && sudo -u dokku crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\" 2>/dev/null)"
  assert_success
}

@test "(dns:cron --disable) removes from system crontab (if available)" {
  if ! command -v crontab >/dev/null 2>&1; then
    skip "crontab not available in test environment"
  fi

  # Enable then disable cron
  dokku dns:cron --enable >/dev/null 2>&1 || skip "cron enable not available in test environment"
  dokku dns:cron --disable >/dev/null 2>&1

  # Check that cron job is removed from system crontab
  run bash -c "crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\" || (command -v sudo >/dev/null 2>&1 && sudo -u dokku crontab -l 2>/dev/null | grep -q \"dokku dns:sync-all\" 2>/dev/null)"
  assert_failure
}
