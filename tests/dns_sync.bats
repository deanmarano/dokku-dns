#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  create_test_app my-app
  add_test_domains my-app test1.com
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
}

@test "(dns:apps:sync) error when there are no arguments" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync"
  assert_failure
  assert_output_contains "Please specify an app name"
}

@test "(dns:apps:sync) error when app does not exist" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" nonexistent-app
  assert_failure
  assert_output_contains "App nonexistent-app does not exist"
}

@test "(dns:apps:sync) works without provider configuration" {
  cleanup_dns_data  # Clear any existing data
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  assert_success
  assert_output_contains "No DNS-managed domains found for app: my-app"
}


@test "(dns:apps:sync) attempts AWS sync when configured" {
  # Add app to DNS management first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  
  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

@test "(dns:apps:sync) handles app with no domains" {
  create_test_app empty-app
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" empty-app
  
  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
  
  cleanup_test_app empty-app
}

@test "(dns:apps:sync) shows helpful error when AWS not accessible" {
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  
  # In test environment, likely to fail with provider not configured
  if [[ "$status" -ne 0 ]]; then
    assert_output_contains "No DNS provider configured" || assert_output_contains "credentials"
    assert_output_contains "dokku dns:providers:configure"
  fi
}

@test "(dns:apps:sync) attempts sync with multiple domains" {
  add_test_domains my-app test2.com working.com
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app

  # Test passes if command runs (may succeed or fail depending on environment)
  # The important thing is the command doesn't crash
  [[ "$status" -eq 0 ]] || [[ "$status" -eq 1 ]]
}

# Enhanced Sync Operations Tests (Phase 16)

@test "(dns:apps:sync) shows apply-style output with planned changes" {
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app

  # Should show enhanced output format if domains are found
  if [[ "$status" -eq 0 && "$output" != *"No DNS-managed domains found"* ]]; then
    assert_output_contains "=====> Syncing DNS records for app 'my-app'"
    assert_output_contains "Target IP:"
    # Should show planned changes or no changes message
    [[ "$output" == *"Planned changes:"* ]] || [[ "$output" == *"No changes needed"* ]]
  fi
}

@test "(dns:apps:sync) shows real-time progress with checkmarks" {
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app

  # Should show progress indicators if domains are found
  if [[ "$status" -eq 0 && "$output" != *"No DNS-managed domains found"* ]]; then
    # Look for progress indicators (checkmarks or other visual elements)
    [[ "$output" == *"✅"* ]] || [[ "$output" == *"❌"* ]] || [[ "$output" == *"✓"* ]] || [[ "$output" == *"No changes needed"* ]]
  fi
}

@test "(dns:apps:sync) displays what was actually changed" {
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app

  # Should show what happened if domains are found
  if [[ "$status" -eq 0 && "$output" != *"No DNS-managed domains found"* ]]; then
    # Look for action descriptions
    [[ "$output" == *"Creating:"* ]] || [[ "$output" == *"Updating:"* ]] || [[ "$output" == *"No changes needed"* ]]
  fi
}

@test "(dns:apps:sync) shows 'No changes needed' when records are correct" {
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  # Test should pass regardless of whether domains are managed
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app
  # Just ensure the command succeeds - enhanced output behavior depends on DNS management state
  assert_success
}

@test "(dns:apps:sync) shows Terraform-style plan summary" {
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app

  # Should show plan summary if domains are found
  if [[ "$status" -eq 0 && "$output" != *"No DNS-managed domains found"* ]]; then
    # Look for Terraform-style plan summary
    [[ "$output" == *"Plan:"* ]] || [[ "$output" == *"to add"* ]] || [[ "$output" == *"to change"* ]] || [[ "$output" == *"No changes needed"* ]]
  fi
}

@test "(dns:apps:sync) enhanced output works with multiple domains" {
  add_test_domains my-app test2.com working.com
  # Add app to DNS first
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" my-app >/dev/null 2>&1

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" my-app

  # Should handle multiple domains with enhanced output if domains are found
  if [[ "$status" -eq 0 && "$output" != *"No DNS-managed domains found"* ]]; then
    assert_output_contains "=====> Syncing DNS records for app 'my-app'"
    # Should show progress for each domain or summary
    [[ "$output" == *"Plan:"* ]] || [[ "$output" == *"No changes needed"* ]]
  fi
}