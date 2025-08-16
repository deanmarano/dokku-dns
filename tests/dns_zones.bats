#!/usr/bin/env bats

load test_helper

setup() {
    # Use the test environment's PLUGIN_DATA_ROOT that's already set up
    # Don't override it since the config file will override it back
    
    # Setup test environment - make sure the directory exists and is clean
    mkdir -p "$PLUGIN_DATA_ROOT"
    rm -rf "$PLUGIN_DATA_ROOT"/*
}

teardown() {
    rm -rf "$PLUGIN_DATA_ROOT"
}

# Helper function to run dns:zones command
dns_zones() {
    run "$PLUGIN_ROOT/subcommands/zones" "$@"
}

# Helper function to setup a mock provider
setup_mock_provider() {
    local provider="${1:-aws}"
    # Ensure the PLUGIN_DATA_ROOT directory exists
    mkdir -p "$PLUGIN_DATA_ROOT"
    echo "$provider" > "$PLUGIN_DATA_ROOT/PROVIDER"
}

# Mock AWS CLI for testing
create_mock_aws() {
    # Create a mock aws command that returns test data
    local BIN_DIR="$PLUGIN_DATA_ROOT/bin"
    mkdir -p "$BIN_DIR"
    cat > "$BIN_DIR/aws" << 'EOF'
#!/bin/bash
case "$*" in
    "sts get-caller-identity"*)
        echo '{"UserId":"AIDAEXAMPLE","Account":"123456789012","Arn":"arn:aws:iam::123456789012:user/test"}'
        ;;
    "route53 list-hosted-zones --query length(HostedZones) --output text")
        echo "2"
        ;;
    "route53 list-hosted-zones --query HostedZones[].[Id,Name,ResourceRecordSetCount,Config.Comment] --output text")
        cat << 'ZONES_DATA'
/hostedzone/Z123456789ABCDEF	example.com.	5	Primary domain zone
/hostedzone/Z987654321ZYXWVU	test.org.	3	None
ZONES_DATA
        ;;
    "route53 list-hosted-zones --query HostedZones[?Name=='example.com.'].Id --output text")
        echo "/hostedzone/Z123456789ABCDEF"
        ;;
    "route53 list-hosted-zones --query HostedZones[?Name=='test.org.'].Id --output text")
        echo "/hostedzone/Z987654321ZYXWVU"
        ;;
    "route53 list-hosted-zones --query HostedZones[?Name=='nonexistent.com.'].Id --output text")
        echo ""
        ;;
    "route53 list-hosted-zones --query HostedZones[].Name --output text")
        echo -e "example.com.\ttest.org."
        ;;
    "route53 list-resource-record-sets --hosted-zone-id Z123456789ABCDEF --query ResourceRecordSets[?Type==\`A\`].Name --output text")
        echo -e "app1.example.com.\tapi.example.com.\twww.example.com."
        ;;
    "route53 list-resource-record-sets --hosted-zone-id Z987654321ZYXWVU --query ResourceRecordSets[?Type==\`A\`].Name --output text")
        echo -e "staging.test.org.\tdemo.test.org."
        ;;
    "route53 get-hosted-zone --id Z123456789ABCDEF --query HostedZone.ResourceRecordSetCount --output text")
        echo "5"
        ;;
    "route53 get-hosted-zone --id Z123456789ABCDEF --query HostedZone.Config.Comment --output text")
        echo "Primary domain zone"
        ;;
    "route53 get-hosted-zone --id Z123456789ABCDEF --query HostedZone.Config.PrivateZone --output text")
        echo "false"
        ;;
    "route53 get-hosted-zone --id Z123456789ABCDEF --query DelegationSet.NameServers --output text")
        echo "ns1.example.com	ns2.example.com"
        ;;
    "route53 list-resource-record-sets --hosted-zone-id Z123456789ABCDEF --query ResourceRecordSets[?Type==\`A\`].[Name,ResourceRecords[0].Value] --output text")
        cat << 'A_RECORDS'
example.com.	1.2.3.4
www.example.com.	1.2.3.4
api.example.com.	1.2.3.5
A_RECORDS
        ;;
    "route53 list-resource-record-sets --hosted-zone-id Z123456789ABCDEF --query ResourceRecordSets[?Type!=\`A\`].[Type,Name] --output text")
        cat << 'OTHER_RECORDS'
CNAME	mail.example.com.
MX	example.com.
NS	example.com.
SOA	example.com.
OTHER_RECORDS
        ;;
    "route53 get-hosted-zone --id Z123456789ABCDEF --output json")
        cat << 'ZONE_DETAILS'
{
  "HostedZone": {
    "Id": "/hostedzone/Z123456789ABCDEF",
    "Name": "example.com.",
    "ResourceRecordSetCount": 5,
    "CallerReference": "test-ref-123",
    "Config": {
      "Comment": "Primary domain zone",
      "PrivateZone": false
    }
  },
  "DelegationSet": {
    "NameServers": [
      "ns1.example.com",
      "ns2.example.com"
    ]
  }
}
ZONE_DETAILS
        ;;
    "route53 list-resource-record-sets --hosted-zone-id Z123456789ABCDEF --output json")
        cat << 'RECORDS_JSON'
{
  "ResourceRecordSets": [
    {
      "Name": "example.com.",
      "Type": "A",
      "ResourceRecords": [{"Value": "1.2.3.4"}]
    },
    {
      "Name": "www.example.com.",
      "Type": "A", 
      "ResourceRecords": [{"Value": "1.2.3.5"}]
    },
    {
      "Name": "example.com.",
      "Type": "NS",
      "ResourceRecords": [{"Value": "ns1.example.com"}]
    }
  ]
}
RECORDS_JSON
        ;;
    *)
        echo "Mock AWS CLI - command not implemented: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$BIN_DIR/aws"
    export PATH="$BIN_DIR:$PATH"
}

# Mock dokku commands
create_mock_dokku() {
    local BIN_DIR="$PLUGIN_DATA_ROOT/bin"
    mkdir -p "$BIN_DIR"
    cat > "$BIN_DIR/dokku" << 'EOF'
#!/bin/bash
case "$*" in
    "apps:list")
        echo "=====> My Apps"
        echo "app1"
        echo "staging-app"
        ;;
    "domains:report app1 --domains-app-vhosts")
        echo "app1.example.com api.example.com"
        ;;
    "domains:report staging-app --domains-app-vhosts")
        echo "staging.test.org"
        ;;
    "domains:report "*" --domains-app-vhosts")
        echo ""
        ;;
    *)
        echo "Mock dokku - command not implemented: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$BIN_DIR/dokku"
    export PATH="$BIN_DIR:$PATH"
}


@test "(dns:zones) fails when no provider configured" {
    dns_zones
    assert_failure
    assert_output_contains "No DNS provider configured"
}

@test "(dns:zones) lists AWS zones when provider configured" {
    setup_mock_provider "aws"
    create_mock_aws
    
    dns_zones
    assert_success
    assert_output_contains "DNS Zones Status (aws provider)"
    assert_output_contains "example.com"
    assert_output_contains "test.org"
}

@test "(dns:zones) shows cloudflare not implemented message" {
    setup_mock_provider "cloudflare"
    
    dns_zones
    assert_success
    assert_output_contains "Cloudflare zones management not yet implemented"
}

@test "(dns:zones) fails with unsupported provider" {
    setup_mock_provider "unsupported"
    
    dns_zones
    assert_failure
    assert_output_contains "Unsupported provider for zones management: unsupported"
}

@test "(dns:zones --enable) requires zone name argument" {
    setup_mock_provider "aws"
    
    dns_zones --enable
    assert_failure
    assert_output_contains "--enable requires either a zone name or --all flag"
}

@test "(dns:zones --disable) requires zone name argument" {
    setup_mock_provider "aws"
    
    dns_zones --disable
    assert_failure
    assert_output_contains "--disable requires either a zone name or --all flag"
}

@test "(dns:zones --enable --disable) fails with multiple actions" {
    setup_mock_provider "aws"
    
    dns_zones --enable --disable
    assert_failure
    assert_output_contains "Cannot use both --enable and --disable flags together"
}

@test "(dns:zones --enable with conflicting zone) fails with multiple actions" {
    setup_mock_provider "aws"
    
    dns_zones example.com --enable test.org
    assert_failure
    assert_output_contains "Cannot specify zone name and action flags together"
}

@test "(dns:zones --enable) fails when zone not found" {
    setup_mock_provider "aws"
    create_mock_aws
    
    dns_zones --enable "nonexistent.com"
    assert_failure
    assert_output_contains "Zone 'nonexistent.com' not found in Route53"
}

@test "(dns:zones --enable) works with valid zone" {
    setup_mock_provider "aws"
    create_mock_aws
    create_mock_dokku
    
    dns_zones --enable "example.com"
    assert_success
    assert_output_contains "Enabling DNS management for zone: example.com"
    assert_output_contains "Discovering domains in zone"
}

@test "(dns:zones --disable) removes domains from zone" {
    setup_mock_provider "aws"
    
    # Setup some managed domains first
    mkdir -p "$PLUGIN_DATA_ROOT/app1"
    echo "app1.example.com" > "$PLUGIN_DATA_ROOT/app1/DOMAINS"
    echo "api.example.com" >> "$PLUGIN_DATA_ROOT/app1/DOMAINS"
    echo "app1" > "$PLUGIN_DATA_ROOT/LINKS"
    
    dns_zones --disable "example.com"
    assert_success
    assert_output_contains "Disabling DNS management for zone: example.com"
    assert_output_contains "• app1: app1.example.com api.example.com"
    assert_output_contains "Zone disablement complete"
    assert_output_contains "Removed 2 domains from 1 app"
}

@test "(dns:zones --enable --all) processes all zones" {
    setup_mock_provider "aws"
    create_mock_aws
    create_mock_dokku
    
    dns_zones --enable --all
    assert_success
    assert_output_contains "Enabling DNS management for all zones"
    assert_output_contains "Processing zone: example.com"
    assert_output_contains "Processing zone: test.org"
}

@test "(dns:zones) shows management commands" {
    setup_mock_provider "aws"
    create_mock_aws
    
    dns_zones
    assert_success
    assert_output_contains "Management Commands"
    assert_output_contains "Enable zone: dokku dns:zones --enable"
    assert_output_contains "Disable zone: dokku dns:zones --disable"
    assert_output_contains "Enable all zones: dokku dns:zones --enable --all"
}

@test "(dns:zones) handles zones with managed domains" {
    setup_mock_provider "aws"
    create_mock_aws
    
    # Setup some managed domains
    mkdir -p "$PLUGIN_DATA_ROOT/app1"
    echo "app1.example.com" > "$PLUGIN_DATA_ROOT/app1/DOMAINS"
    echo "app1" > "$PLUGIN_DATA_ROOT/LINKS"
    
    dns_zones
    assert_success
    assert_output_contains "ACTIVE"
    assert_output_contains "Managed domains"
}

@test "(dns:zones <zone>) shows zone details" {
    setup_mock_provider "aws"
    create_mock_aws
    
    dns_zones example.com
    assert_success
    assert_output_contains "DNS Zone Details: example.com"
}

@test "(dns:zones <zone>) fails when zone not found" {
    setup_mock_provider "aws"
    create_mock_aws
    
    dns_zones nonexistent.com
    assert_failure
    assert_output_contains "Zone 'nonexistent.com' not found in Route53"
}

@test "(dns:zones) handles unknown flag" {
    setup_mock_provider "aws"
    
    dns_zones --invalid-flag
    assert_failure
    assert_output_contains "Unknown option: --invalid-flag"
}

@test "(dns:zones --enable) fails with non-AWS provider" {
    setup_mock_provider "cloudflare"
    
    dns_zones --enable "example.com"
    assert_failure
    assert_output_contains "Zone management is currently only supported for AWS Route53 provider"
}

@test "(dns:zones --disable) works without provider restriction" {
    setup_mock_provider "cloudflare"
    
    # Setup some managed domains
    mkdir -p "$PLUGIN_DATA_ROOT/app1"
    echo "app1.example.com" > "$PLUGIN_DATA_ROOT/app1/DOMAINS"
    echo "app1" > "$PLUGIN_DATA_ROOT/LINKS"
    
    dns_zones --disable "example.com"
    assert_success
    assert_output_contains "Disabling DNS management for zone: example.com"
}

@test "(dns:zones --disable) handles empty LINKS file" {
    setup_mock_provider "aws"
    
    # Create empty LINKS file
    touch "$PLUGIN_DATA_ROOT/LINKS"
    
    dns_zones --disable "example.com"
    assert_success
    assert_output_contains "No apps are currently managed by DNS"
}

@test "(dns:zones --enable) handles no Dokku apps" {
    setup_mock_provider "aws"
    create_mock_aws
    
    # Mock dokku apps:list to return no apps
    mkdir -p "$PLUGIN_DATA_ROOT/bin"
    cat > "$PLUGIN_DATA_ROOT/bin/dokku" << 'EOF'
#!/bin/bash
case "$*" in
    "apps:list")
        echo "=====> My Apps"
        ;;
    *)
        echo "Mock dokku - command not implemented: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$PLUGIN_DATA_ROOT/bin/dokku"
    export PATH="$PLUGIN_DATA_ROOT/bin:$PATH"
    
    dns_zones --enable "example.com"
    assert_success
    assert_output_contains "No Dokku apps found"
}

# Helper functions for test assertions
assert_output_contains() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        echo "Expected file to exist: $file"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local expected="$2"
    if [[ ! -f "$file" ]]; then
        echo "File does not exist: $file"
        return 1
    fi
    if ! grep -q "$expected" "$file"; then
        echo "Expected file $file to contain: $expected"
        echo "Actual content:"
        cat "$file"
        return 1
    fi
}

@test "(dns:zones --disable --all) removes all apps from DNS management" {
    setup_mock_provider "aws"
    
    # Setup some managed domains
    mkdir -p "$PLUGIN_DATA_ROOT/testapp1" "$PLUGIN_DATA_ROOT/testapp2"
    echo -e "example.com\napi.example.com" > "$PLUGIN_DATA_ROOT/testapp1/DOMAINS"
    echo "test.org" > "$PLUGIN_DATA_ROOT/testapp2/DOMAINS"
    echo -e "testapp1\ntestapp2" > "$PLUGIN_DATA_ROOT/LINKS"
    
    dns_zones --disable --all
    assert_success
    assert_output_contains "Disabling DNS management for all zones"
    assert_output_contains "Removing app 'testapp1' from DNS management (2 domains)"
    assert_output_contains "Removing app 'testapp2' from DNS management (1 domains)"
    assert_output_contains "Apps removed from DNS: 2"
    assert_output_contains "Total domains removed: 3"
    
    # Verify cleanup
    assert_output_contains "All DNS management has been disabled"
    run test -f "$PLUGIN_DATA_ROOT/testapp1/DOMAINS"
    assert_failure
    run test -f "$PLUGIN_DATA_ROOT/testapp2/DOMAINS"
    assert_failure
    
    # LINKS file should be empty
    run cat "$PLUGIN_DATA_ROOT/LINKS"
    assert_success
    assert_output ""
}

@test "(dns:zones --disable --all) handles no managed apps gracefully" {
    setup_mock_provider "aws"
    
    dns_zones --disable --all
    assert_success
    assert_output_contains "Disabling DNS management for all zones"
    assert_output_contains "No apps are currently managed by DNS"
}

@test "(dns:zones --all without action) shows zones status" {
    setup_mock_provider "aws"
    create_mock_aws
    
    dns_zones --all
    assert_success
    assert_output_contains "DNS Zones Status"
}

@test "(dns:zones --enable without zone or --all) fails with validation error" {
    setup_mock_provider "aws"
    
    dns_zones --enable
    assert_failure
    assert_output_contains "--enable requires either a zone name or --all flag"
}

@test "(dns:zones --disable without zone or --all) fails with validation error" {
    setup_mock_provider "aws"
    
    dns_zones --disable
    assert_failure
    assert_output_contains "--disable requires either a zone name or --all flag"
}

@test "(dns:zones --disable --all) shows helpful next steps" {
    setup_mock_provider "aws"
    
    # Setup some managed domains
    mkdir -p "$PLUGIN_DATA_ROOT/testapp"
    echo "example.com" > "$PLUGIN_DATA_ROOT/testapp/DOMAINS"
    echo "testapp" > "$PLUGIN_DATA_ROOT/LINKS"
    
    dns_zones --disable --all
    assert_success
    assert_output_contains "To re-enable: dokku dns:zones --enable --all"
    assert_output_contains "Or add apps individually: dokku dns:add <app>"
}