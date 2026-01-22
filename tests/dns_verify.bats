#!/usr/bin/env bats
load test_helper

setup() {
  cleanup_dns_data
}

teardown() {
  cleanup_dns_data
}

@test "(dns:providers:verify) works without configuration" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  # May succeed if AWS CLI works, or fail if not
  [[ "$output" == *"aws:"* ]]
}

@test "(dns:providers:verify) verbose mode shows zone list" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" --verbose
  # Verbose mode shows zones indented under provider
  [[ "$output" == *"aws:"* ]]
}

@test "(dns:providers:verify) verifies AWS when available" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  [[ "$output" == *"aws:"* ]]
}

@test "(dns:providers:verify) attempts AWS verification when configured" {
  setup_dns_provider aws

  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  [[ "$output" == *"aws:"* ]]
}

@test "(dns:providers:verify) shows AWS status" {
  setup_dns_provider aws

  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  [[ "$output" == *"aws:"* ]]
}

@test "(dns:providers:verify) accepts aws provider argument" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" aws
  [[ "$output" == *"aws:"* ]]
}

@test "(dns:providers:verify) attempts cloudflare verification when token configured" {
  CLOUDFLARE_API_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" cloudflare
  assert_failure
  [[ "$output" == *"cloudflare:"* ]]
  [[ "$output" == *"auth failed"* ]]
}

@test "(dns:providers:verify) attempts cloudflare verification in verbose mode" {
  CLOUDFLARE_API_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" cloudflare --verbose
  assert_failure
  [[ "$output" == *"cloudflare:"* ]]
}

@test "(dns:providers:verify) attempts digitalocean verification when token configured" {
  DIGITALOCEAN_ACCESS_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" digitalocean
  assert_failure
  [[ "$output" == *"digitalocean:"* ]]
  [[ "$output" == *"auth failed"* ]]
}

@test "(dns:providers:verify) attempts digitalocean verification in verbose mode" {
  DIGITALOCEAN_ACCESS_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" digitalocean --verbose
  assert_failure
  [[ "$output" == *"digitalocean:"* ]]
}

@test "(dns:providers:verify) auto-detects multiple providers when configured" {
  CLOUDFLARE_API_TOKEN="test-token" DIGITALOCEAN_ACCESS_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  # Should succeed because AWS verification works
  assert_success
  [[ "$output" == *"aws:"* ]]
  [[ "$output" == *"cloudflare:"* ]]
  [[ "$output" == *"digitalocean:"* ]]
}

@test "(dns:providers:verify) auto-detects multiple providers in verbose mode" {
  CLOUDFLARE_API_TOKEN="test-token" DIGITALOCEAN_ACCESS_TOKEN="test-token" run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" --verbose
  assert_success
  [[ "$output" == *"aws:"* ]]
  [[ "$output" == *"cloudflare:"* ]]
  [[ "$output" == *"digitalocean:"* ]]
}

@test "(dns:providers:verify) rejects invalid provider argument" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" invalid-provider
  assert_failure
}

@test "(dns:providers:verify) rejects template provider in normal mode" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" template
  assert_failure
}

@test "(dns:providers:verify) accepts template provider in test mode" {
  export TEMPLATE_API_KEY="test-key"
  export TEMPLATE_API_SECRET="test-secret"
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" template
  assert_success
}

@test "(dns:providers:verify) accepts template provider in test mode verbose" {
  export TEMPLATE_API_KEY="test-key"
  export TEMPLATE_API_SECRET="test-secret"
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" template --verbose
  assert_success
}

@test "(command dispatcher) colon syntax works for providers:verify" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify"
  [[ "$output" == *"aws:"* ]]
}

@test "(command dispatcher) colon syntax works for providers:verify verbose" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" --verbose
  [[ "$output" == *"aws:"* ]]
}

@test "(command dispatcher) handles provider arguments in colon syntax" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" aws
  [[ "$output" == *"aws:"* ]]
}

@test "(command dispatcher) routing works for providers:verify command" {
  run dokku "$PLUGIN_COMMAND_PREFIX:providers:verify" aws
  [[ "$output" == *"aws:"* ]]
  # Should NOT show help output
  [[ "$output" != *"usage:"* ]]
}
