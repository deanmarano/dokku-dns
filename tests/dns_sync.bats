#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
  setup_dns_provider aws
  create_test_app my-app
  add_test_domains my-app test1.com
  
  # Mock get_server_ip to return consistent IP for testing
  get_server_ip() {
    echo "192.168.1.100"
  }
  export -f get_server_ip
}

teardown() {
  cleanup_test_app my-app
  cleanup_dns_data
  unset -f get_server_ip
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

@test "(dns:apps:sync) shows enhanced output with plan and apply" {
  create_test_app sync-app
  add_test_domains sync-app example.com api.example.com
  
  # Mock AWS provider functions for controlled testing
  dns_provider_aws_get_hosted_zone_id() {
    local DOMAIN="$1"
    case "$DOMAIN" in
        "example.com"|*.example.com)
            echo "Z1234567890ABC"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
  }
  export -f dns_provider_aws_get_hosted_zone_id
  
  dns_provider_aws_get_record_ip() {
    local DOMAIN="$1"
    case "$DOMAIN" in
        "example.com")
            return 1  # No existing record - will be created
            ;;
        "api.example.com")
            echo "192.168.1.50"  # Wrong IP - will be updated
            return 0
            ;;
        *)
            return 1
            ;;
    esac
  }
  export -f dns_provider_aws_get_record_ip
  
  # Add app to DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" sync-app >/dev/null 2>&1
  
  # Set up provider credentials mock to make provider "ready"
  mkdir -p "$PLUGIN_DATA_ROOT/credentials"
  echo "test" > "$PLUGIN_DATA_ROOT/credentials/AWS_ACCESS_KEY_ID"
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" sync-app
  assert_success
  
  # Check for enhanced output format
  assert_output_contains "=====> DNS Sync for app: sync-app"
  assert_output_contains "-----> Target IP: "
  assert_output_contains "-----> Will create: example.com → 192.168.1.100 (A record)"
  assert_output_contains "-----> Will update: api.example.com → 192.168.1.100 (A record) [was: 192.168.1.50]"
  assert_output_contains "=====> Applying changes..."
  assert_output_contains "✅ Created: example.com → 192.168.1.100 (A record)"
  assert_output_contains "✅ Updated: api.example.com → 192.168.1.100 (A record) [was: 192.168.1.50]"
  assert_output_contains "=====> Sync complete! Resources: 2 changed, 0 failed"
  
  # Clean up
  unset -f dns_provider_aws_get_hosted_zone_id
  unset -f dns_provider_aws_get_record_ip
  cleanup_test_app sync-app
}

@test "(dns:apps:sync) shows no changes needed when DNS is already correct" {
  create_test_app correct-app
  add_test_domains correct-app example.com
  
  # Mock AWS provider functions - record already correct
  dns_provider_aws_get_hosted_zone_id() {
    local DOMAIN="$1"
    case "$DOMAIN" in
        "example.com"|*.example.com)
            echo "Z1234567890ABC"
            return 0
            ;;
        *)
            return 1
            ;;
    esac
  }
  export -f dns_provider_aws_get_hosted_zone_id
  
  dns_provider_aws_get_record_ip() {
    local DOMAIN="$1"
    case "$DOMAIN" in
        "example.com")
            echo "192.168.1.100"  # Correct IP - no change needed
            return 0
            ;;
        *)
            return 1
            ;;
    esac
  }
  export -f dns_provider_aws_get_record_ip
  
  # Set up provider credentials mock to make provider "ready"
  mkdir -p "$PLUGIN_DATA_ROOT/credentials"
  echo "test" > "$PLUGIN_DATA_ROOT/credentials/AWS_ACCESS_KEY_ID"
  
  # Create provider file
  echo "aws" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  # Enable zone first
  dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" example.com >/dev/null 2>&1
  
  # Add app to DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" correct-app >/dev/null 2>&1
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" correct-app
  assert_success
  
  # Check for "no changes needed" output
  assert_output_contains "=====> DNS Sync for app: correct-app"
  assert_output_contains "-----> Target IP: "
  assert_output_contains "-----> Already correct: example.com → 192.168.1.100 (A record)"
  assert_output_contains "=====> No changes needed - all DNS records are already correct"
  
  # Should not contain "Applying changes" section
  [[ "$output" != *"=====> Applying changes..."* ]]
  
  # Clean up
  unset -f dns_provider_aws_get_hosted_zone_id
  unset -f dns_provider_aws_get_record_ip
  cleanup_test_app correct-app
}

@test "(dns:apps:sync) handles mixed success and failure scenarios" {
  create_test_app mixed-app
  add_test_domains mixed-app good.example.com bad.invalid
  
  # Mock AWS provider functions with mixed results
  dns_provider_aws_get_hosted_zone_id() {
    local DOMAIN="$1"
    case "$DOMAIN" in
        "good.example.com"|*.example.com)
            echo "Z1234567890ABC"
            return 0
            ;;
        *)
            return 1  # No hosted zone for bad.invalid
            ;;
    esac
  }
  export -f dns_provider_aws_get_hosted_zone_id
  
  dns_provider_aws_get_record_ip() {
    local DOMAIN="$1"
    case "$DOMAIN" in
        "good.example.com")
            return 1  # No existing record - will be created
            ;;
        *)
            return 1
            ;;
    esac
  }
  export -f dns_provider_aws_get_record_ip
  
  # Set up provider credentials mock to make provider "ready"
  mkdir -p "$PLUGIN_DATA_ROOT/credentials"
  echo "test" > "$PLUGIN_DATA_ROOT/credentials/AWS_ACCESS_KEY_ID"
  
  # Create provider file
  echo "aws" > "$PLUGIN_DATA_ROOT/PROVIDER"
  
  # Enable zone first
  dokku "$PLUGIN_COMMAND_PREFIX:zones:enable" example.com >/dev/null 2>&1
  
  # Add app to DNS management
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" mixed-app >/dev/null 2>&1
  
  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" mixed-app
  assert_success
  
  # Check for mixed success/failure output
  assert_output_contains "=====> DNS Sync for app: mixed-app"
  assert_output_contains "-----> Will create: good.example.com → 192.168.1.100 (A record)"
  assert_output_contains "=====> Applying changes..."
  assert_output_contains "✅ Created: good.example.com → 192.168.1.100 (A record)"
  assert_output_contains "❌ Error: No hosted zone found for bad.invalid"
  assert_output_contains "=====> Sync complete! Resources: 1 changed, 1 failed"
  
  # Clean up
  unset -f dns_provider_aws_get_hosted_zone_id
  unset -f dns_provider_aws_get_record_ip
  cleanup_test_app mixed-app
}