#!/usr/bin/env bats

load test_helper

setup() {
    # Skip setup in Docker environment - apps and provider already configured
    if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
        cleanup_dns_data
    fi
}

teardown() {
    # Skip teardown in Docker environment to preserve setup
    if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
        cleanup_dns_data
    fi
}

@test "(triggers) post-create trigger exists and is executable" {
    assert_file_exists "$PLUGIN_ROOT/post-create"
    assert_file_executable "$PLUGIN_ROOT/post-create"
}

@test "(triggers) pre-delete trigger exists and is executable" {
    assert_file_exists "$PLUGIN_ROOT/pre-delete"
    assert_file_executable "$PLUGIN_ROOT/pre-delete"
}

@test "(triggers) post-domains-update trigger exists and is executable" {
    assert_file_exists "$PLUGIN_ROOT/post-domains-update"
    assert_file_executable "$PLUGIN_ROOT/post-domains-update"
}

@test "(triggers) post-create works with no DNS provider configured" {
    # Should not fail even if no provider is configured
    run "$PLUGIN_ROOT/post-create" "test-app"
    assert_success
}

@test "(triggers) post-create works with DNS provider configured" {
    setup_dns_provider "aws"
    
    run "$PLUGIN_ROOT/post-create" "test-app"
    assert_success
    assert_output_contains "DNS: Checking if app 'test-app' should be added"
}

@test "(triggers) pre-delete works with app not in DNS management" {
    # Should not fail if app is not managed by DNS
    run "$PLUGIN_ROOT/pre-delete" "test-app"
    assert_success
}

@test "(triggers) pre-delete cleans up DNS management" {
    setup_dns_provider "aws"
    
    # Simulate app being managed by DNS
    echo "test-app" > "$PLUGIN_DATA_ROOT/LINKS"
    mkdir -p "$PLUGIN_DATA_ROOT/test-app"
    echo "example.com" > "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
    
    run "$PLUGIN_ROOT/pre-delete" "test-app"
    assert_success
    assert_output_contains "DNS: Cleaning up DNS management for app 'test-app'"
    assert_output_contains "example.com"
    
    # Check cleanup happened
    assert_file_not_exists "$PLUGIN_DATA_ROOT/test-app"
    if [[ -f "$PLUGIN_DATA_ROOT/LINKS" ]]; then
        refute_line_in_file "test-app" "$PLUGIN_DATA_ROOT/LINKS"
    fi
}

@test "(triggers) post-domains-update works with no DNS provider configured" {
    # Should not fail even if no provider is configured
    run "$PLUGIN_ROOT/post-domains-update" "test-app" "add" "example.com"
    assert_success
}

@test "(triggers) post-domains-update adds domain to DNS management" {
    setup_dns_provider "aws"
    
    run "$PLUGIN_ROOT/post-domains-update" "test-app" "add" "example.com"
    assert_success
    assert_output_contains "DNS: Domain 'example.com' added to app 'test-app'"
    assert_output_contains "DNS: Domain 'example.com' added to DNS tracking"
    assert_output_contains "DNS: Syncing DNS records for 'test-app'"
}

@test "(triggers) post-domains-update works with remove action and no DNS provider" {
    # Should not fail even if no provider is configured
    run "$PLUGIN_ROOT/post-domains-update" "test-app" "remove" "example.com"
    assert_success
}

@test "(triggers) post-domains-update removes domain from DNS management" {
    setup_dns_provider "aws"
    
    # Setup app with domains
    echo "test-app" > "$PLUGIN_DATA_ROOT/LINKS"
    mkdir -p "$PLUGIN_DATA_ROOT/test-app"
    echo -e "example.com\napi.example.com" > "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
    
    run "$PLUGIN_ROOT/post-domains-update" "test-app" "remove" "example.com"
    assert_success
    assert_output_contains "DNS: Domain 'example.com' removed from DNS tracking"
    
    # Check domain was removed but app still managed
    assert_file_exists "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
    refute_line_in_file "example.com" "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
    assert_line_in_file "api.example.com" "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
}

@test "(triggers) post-domains-update removes app when last domain is removed" {
    setup_dns_provider "aws"
    
    # Setup app with single domain
    echo "test-app" > "$PLUGIN_DATA_ROOT/LINKS"
    mkdir -p "$PLUGIN_DATA_ROOT/test-app"
    echo "example.com" > "$PLUGIN_DATA_ROOT/test-app/DOMAINS"
    
    run "$PLUGIN_ROOT/post-domains-update" "test-app" "remove" "example.com"
    assert_success
    assert_output_contains "DNS: App 'test-app' has no domains left, removing from DNS management"
    
    # Check app was completely removed
    assert_file_not_exists "$PLUGIN_DATA_ROOT/test-app"
    if [[ -f "$PLUGIN_DATA_ROOT/LINKS" ]]; then
        refute_line_in_file "test-app" "$PLUGIN_DATA_ROOT/LINKS"
    fi
}

