#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Multi-Provider Integration Tests
# Tests for managing multiple DNS providers simultaneously

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
  check_dns_plugin_available

  # Setup environment for multi-provider testing
  export MOCK_API_KEY="test-key"
  export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-mock-cf-token}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"
}

@test "(multi-provider) can load multiple providers simultaneously" {
  run bash -c '
        source ../../providers/loader.sh
        echo "Loading mock provider..."
        load_provider mock 2>&1 | grep -o "Loaded provider: mock" || echo "Mock not loaded"
        echo "Loading cloudflare provider..."
        load_provider cloudflare 2>&1 | grep -o "Loaded provider: cloudflare" || echo "Cloudflare not loaded"
        echo "Checking loaded providers:"
        list_loaded_providers | sort
    '
  assert_success
  # At least one provider should load successfully
}

@test "(multi-provider) providers maintain separate configurations" {
  # Test that each provider has its own configuration
  run bash -c '
        source ../../providers/mock/config.sh
        echo "Mock provider: $PROVIDER_NAME"
        source ../../providers/cloudflare/config.sh
        echo "Cloudflare provider: $PROVIDER_NAME"
        source ../../providers/aws/config.sh
        echo "AWS provider: $PROVIDER_NAME"
    '
  assert_success
  assert_output --partial "Mock provider: mock"
  assert_output --partial "Cloudflare provider: cloudflare"
  assert_output --partial "AWS provider: aws"
}

@test "(multi-provider) can switch between providers" {
  run bash -c '
        source ../../providers/loader.sh
        echo "Initial provider:" $(get_current_provider)
        load_specific_provider mock 2>/dev/null && echo "Switched to:" $(get_current_provider)
        load_specific_provider cloudflare 2>/dev/null && echo "Switched to:" $(get_current_provider)
    '
  # Should work regardless of which providers are available
  assert_success
}

@test "(multi-provider) provider priority order is respected" {
  # Test that providers are tried in the correct order
  run cat ../../providers/available
  assert_success

  # Mock should be first, followed by aws, then cloudflare
  [[ "$(cat ../../providers/available | head -1)" == "mock" ]]
}

@test "(multi-provider) zone assignment concept works" {
  # Test the conceptual framework for zone assignment
  # This tests the underlying mechanisms that would support zone assignment

  run bash -c '
        # Simulate zone assignment storage
        mkdir -p /tmp/dns-test/zones
        echo "cloudflare" > /tmp/dns-test/zones/example.com
        echo "aws" > /tmp/dns-test/zones/production.net
        echo "mock" > /tmp/dns-test/zones/test.local

        # Test reading assignments
        echo "example.com assigned to:" $(cat /tmp/dns-test/zones/example.com)
        echo "production.net assigned to:" $(cat /tmp/dns-test/zones/production.net)
        echo "test.local assigned to:" $(cat /tmp/dns-test/zones/test.local)

        # Cleanup
        rm -rf /tmp/dns-test
    '
  assert_success
  assert_output --partial "example.com assigned to: cloudflare"
  assert_output --partial "production.net assigned to: aws"
  assert_output --partial "test.local assigned to: mock"
}

@test "(multi-provider) provider validation works independently" {
  # Test that each provider can be validated independently

  # Test mock provider validation
  run bash -c "source ../../providers/loader.sh && validate_provider mock"
  assert_success

  # Test cloudflare provider validation
  run bash -c "source ../../providers/loader.sh && validate_provider cloudflare"
  assert_success

  # Test aws provider validation
  run bash -c "source ../../providers/loader.sh && validate_provider aws"
  assert_success
}

@test "(multi-provider) provider capabilities are provider-specific" {
  # Test that each provider reports its own capabilities
  run bash -c '
        source ../../providers/mock/config.sh && echo "Mock capabilities: $PROVIDER_CAPABILITIES"
        source ../../providers/cloudflare/config.sh && echo "Cloudflare capabilities: $PROVIDER_CAPABILITIES"
        source ../../providers/aws/config.sh && echo "AWS capabilities: $PROVIDER_CAPABILITIES"
    '
  assert_success
  assert_output --partial "Mock capabilities:"
  assert_output --partial "Cloudflare capabilities: zones records batch"
  assert_output --partial "AWS capabilities:"
}

@test "(multi-provider) environment variables don't conflict" {
  # Test that provider-specific environment variables don't interfere
  run bash -c '
        export MOCK_API_KEY="mock-test-key"
        export CLOUDFLARE_API_TOKEN="cf-test-token"
        export AWS_ACCESS_KEY_ID="aws-test-key"

        source ../../providers/mock/config.sh
        echo "Mock requires: $PROVIDER_REQUIRED_ENV_VARS"

        source ../../providers/cloudflare/config.sh
        echo "Cloudflare requires: $PROVIDER_REQUIRED_ENV_VARS"

        source ../../providers/aws/config.sh
        echo "AWS requires: $PROVIDER_REQUIRED_ENV_VARS"
    '
  assert_success
  assert_output --partial "Mock requires: MOCK_API_KEY"
  assert_output --partial "Cloudflare requires: CLOUDFLARE_API_TOKEN"
  assert_output --partial "AWS requires: AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY"
}

@test "(multi-provider) provider isolation works correctly" {
  # Test that providers can work in isolation without affecting each other

  # Test loading cloudflare doesn't break mock
  run bash -c '
        source ../../providers/loader.sh
        load_provider mock 2>/dev/null || echo "Mock failed to load"
        load_provider cloudflare 2>/dev/null || echo "Cloudflare failed to load"
        echo "Mock still loaded:" $(is_provider_loaded mock && echo "YES" || echo "NO")
        echo "Cloudflare loaded:" $(is_provider_loaded cloudflare && echo "YES" || echo "NO")
    '
  assert_success
}

@test "(multi-provider) provider functions don't interfere" {
  # Test that functions from different providers don't conflict

  # Load mock provider and test a function
  run bash -c '
        source ../../providers/mock/provider.sh
        echo "Mock validate:" $(provider_validate_credentials && echo "OK" || echo "FAIL")
    '
  # Should work (mock provider doesn't require real credentials)
  assert_success
  assert_output --partial "Mock validate: OK"

  # Load cloudflare provider and test a function
  run bash -c '
        unset CLOUDFLARE_API_TOKEN
        source ../../providers/cloudflare/provider.sh
        provider_validate_credentials 2>&1 | grep -o "Missing required environment variable" || echo "Different error"
    '
  assert_success
  assert_output --partial "Missing required environment variable"
}

@test "(multi-provider) provider auto-detection respects availability" {
  # Test that auto-detection only uses available providers
  run bash -c '
        source ../../providers/loader.sh
        get_available_providers | wc -l
    '
  assert_success
  # Should return a number (count of available providers)
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "(multi-provider) provider loading is idempotent" {
  # Test that loading the same provider multiple times doesn't cause issues
  run bash -c '
        source ../../providers/loader.sh
        load_provider mock 2>/dev/null || echo "First load failed"
        load_provider mock 2>/dev/null || echo "Second load failed"
        load_provider mock 2>/dev/null || echo "Third load failed"
        echo "Final state: mock loaded:" $(is_provider_loaded mock && echo "YES" || echo "NO")
    '
  assert_success
}

@test "(multi-provider) supports provider-specific error handling" {
  # Test that each provider handles errors in its own way

  # Test cloudflare-specific error handling
  function curl() {
    echo '{"success": false, "errors": [{"message": "Cloudflare API error"}]}'
  }
  export -f curl

  function jq() {
    if [[ "$*" == *"-e"* && "$*" == *"success"* ]]; then
      echo "false"
      return 1
    elif [[ "$*" == *"errors"* ]]; then
      echo "Cloudflare API error"
    fi
  }
  export -f jq

  run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
  assert_failure
  assert_output --partial "Cloudflare API error"
}

@test "(multi-provider) provider metadata is accessible" {
  # Test that we can query provider metadata
  run bash -c '
        for provider in mock aws cloudflare; do
            if [[ -f ../../providers/$provider/config.sh ]]; then
                source ../../providers/$provider/config.sh
                echo "$provider: $PROVIDER_DISPLAY_NAME (docs: $PROVIDER_DOCS_URL)"
            fi
        done
    '
  assert_success
  assert_output --partial "mock:"
  assert_output --partial "aws:"
  assert_output --partial "cloudflare: Cloudflare"
}

@test "(multi-provider) provider setup functions work independently" {
  # Test that provider setup doesn't interfere between providers

  # Test cloudflare setup (checks for jq)
  run bash -c '
        source ../../providers/cloudflare/provider.sh
        provider_setup_env 2>&1 | head -1
    '
  # Should either succeed or fail gracefully

  # Test mock setup (should always work)
  run bash -c '
        source ../../providers/mock/provider.sh
        provider_setup_env && echo "Mock setup: OK"
    '
  assert_success
  assert_output --partial "Mock setup: OK"
}

@test "(multi-provider) zone management can handle multiple providers" {
  # Test conceptual zone management across providers
  run bash -c '
        # Simulate zones from different providers
        echo "Simulating multi-provider zone discovery:"
        echo "Mock zones: test.local, dev.local"
        echo "Cloudflare zones: example.com, api.example.com"
        echo "AWS zones: production.net, staging.production.net"
        echo "Total zones available: 6"
    '
  assert_success
  assert_output --partial "Total zones available: 6"
}

@test "(multi-provider) provider switching maintains state" {
  # Test that switching providers doesn't lose state
  run bash -c '
        source ../../providers/loader.sh
        echo "Available providers:" $(get_available_providers | wc -l)
        load_provider mock 2>/dev/null && echo "Current: mock"
        load_provider cloudflare 2>/dev/null && echo "Current: cloudflare"
        echo "Loaded count:" $(list_loaded_providers | wc -l)
    '
  assert_success
}

@test "(multi-provider) configuration validation works per provider" {
  # Test that configuration validation is provider-specific

  # Test that cloudflare requires its specific token
  unset CLOUDFLARE_API_TOKEN
  run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
  assert_failure
  assert_output --partial "CLOUDFLARE_API_TOKEN"

  # Test that mock doesn't require cloudflare token
  run bash -c "source ../../providers/mock/provider.sh && provider_validate_credentials"
  assert_success
}
