#!/usr/bin/env bats

# Load common functions
load bats-common

# DNS Plugin Providers Integration Tests  
# Tests for dns:providers subcommands

# shellcheck disable=SC2154  # status and output are BATS built-in variables

setup() {
    check_dns_plugin_available
}

@test "(dns:report) shows mock provider when AWS CLI not available" {
    run dokku dns:report
    assert_success
    assert_output --partial "DNS Provider: MOCK"
}

@test "(dns:providers:verify) shows AWS CLI status" {
    run dokku dns:providers:verify
    # Command may succeed or fail depending on AWS CLI availability
    # Should show meaningful AWS CLI status either way
    assert_output --partial "AWS CLI"
}

@test "(dns:providers:verify) shows installation instructions when AWS CLI not available" {
    run dokku dns:providers:verify
    # Should show AWS CLI installation instructions when not available
    [[ "$output" =~ (AWS\ CLI\ is\ not\ installed|Please\ install\ it\ first) ]]
}

@test "(providers) cloudflare provider is available in the system" {
    run cat ../../providers/available
    assert_success
    assert_output --partial "cloudflare"
}

@test "(providers) cloudflare provider loads successfully" {
    export CLOUDFLARE_API_TOKEN="test-token-for-integration"
    run bash -c "source ../../providers/loader.sh && load_provider cloudflare 2>&1"
    assert_success
    assert_output --partial "Loaded provider: cloudflare"
}

@test "(providers) cloudflare provider has correct configuration" {
    run bash -c "source ../../providers/cloudflare/config.sh && echo \$PROVIDER_NAME"
    assert_success
    assert_output "cloudflare"

    run bash -c "source ../../providers/cloudflare/config.sh && echo \$PROVIDER_DISPLAY_NAME"
    assert_success
    assert_output "Cloudflare"
}

@test "(providers) cloudflare provider implements required functions" {
    local required_functions=(
        "provider_validate_credentials"
        "provider_list_zones"
        "provider_get_zone_id"
        "provider_get_record"
        "provider_create_record"
        "provider_delete_record"
    )

    for func in "${required_functions[@]}"; do
        run bash -c "source ../../providers/cloudflare/provider.sh && declare -f $func"
        assert_success
    done
}

@test "(providers) cloudflare provider validates structure correctly" {
    run bash -c "source ../../providers/loader.sh && validate_provider cloudflare"
    assert_success
}

@test "(providers) multi-provider detection includes cloudflare" {
    run bash -c "source ../../providers/loader.sh && list_available_providers"
    assert_success
    assert_output --partial "cloudflare"
    assert_output --partial "aws"
    assert_output --partial "mock"
}

@test "(providers) cloudflare provider requires API token" {
    unset CLOUDFLARE_API_TOKEN
    run bash -c "source ../../providers/cloudflare/provider.sh && provider_validate_credentials"
    assert_failure
    assert_output --partial "Missing required environment variable: CLOUDFLARE_API_TOKEN"
}