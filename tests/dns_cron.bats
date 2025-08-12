#!/usr/bin/env bats

load test_helper

setup() {
    # Skip setup in Docker environment - apps and provider already configured
    if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
        cleanup_dns_data
        setup_dns_provider aws
    fi
}

teardown() {
    # Skip teardown in Docker environment to preserve setup
    if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
        cleanup_dns_data
        cleanup_mock_cron
    fi
}

@test "(dns:cron) shows disabled status when no cron job exists" {
    run dns_cron
    assert_success
    assert_output_contains "Status: ❌ DISABLED"
    assert_output_contains "Schedule: N/A"
    assert_output_contains "Enable cron: dokku dns:cron-enable"
}

@test "(dns:cron-enable) fails when no DNS provider configured" {
    # Remove provider file if it exists
    rm -f "$PLUGIN_DATA_ROOT/PROVIDER" >/dev/null 2>&1 || true
    
    run dns_cron_enable
    assert_failure
    assert_output_contains "No DNS provider configured"
    assert_output_contains "dokku dns:configure"
}

@test "(dns:cron-enable) creates cron job when provider configured" {
    # Setup provider
    setup_mock_provider
    
    # Mock crontab commands
    create_mock_crontab
    
    run dns_cron_enable
    assert_success
    assert_output_contains "✅ DNS cron job enabled successfully!"
    assert_output_contains "Schedule: Daily at 2:00 AM"
    assert_output_contains "Command: dokku dns:sync-all"
    
    # Check metadata files were created
    assert [ -f "$PLUGIN_DATA_ROOT/cron/status" ]
    assert [ -f "$PLUGIN_DATA_ROOT/cron/schedule" ]
    assert [ -f "$PLUGIN_DATA_ROOT/cron/enabled_at" ]
    
    # Check status file content
    assert [ "$(cat "$PLUGIN_DATA_ROOT/cron/status")" = "enabled" ]
}

@test "(dns:cron-enable) shows warning when cron job already exists" {
    # Setup provider
    setup_mock_provider
    
    # Mock existing cron job
    create_mock_crontab_with_existing_job
    
    run dns_cron_enable
    assert_success
    assert_output_contains "DNS cron job already exists"
    assert_output_contains "To disable: dokku dns:cron-disable"
}

@test "(dns:cron-disable) fails when no cron job exists" {
    # Mock empty crontab
    create_mock_crontab
    
    run dns_cron_disable
    assert_failure
    assert_output_contains "No DNS cron job found"
    assert_output_contains "Enable with: dokku dns:cron-enable"
}

@test "(dns:cron-disable) removes existing cron job" {
    # Setup provider and cron job
    setup_mock_provider
    create_mock_crontab_with_existing_job
    
    # Create cron metadata
    mkdir -p "$PLUGIN_DATA_ROOT/cron"
    echo "enabled" > "$PLUGIN_DATA_ROOT/cron/status"
    echo "$PLUGIN_DATA_ROOT/cron/sync.log" > "$PLUGIN_DATA_ROOT/cron/log_file"
    
    run dns_cron_disable
    assert_success
    assert_output_contains "✅ DNS cron job disabled successfully!"
    assert_output_contains "Automated DNS synchronization is now inactive"
    
    # Check status was updated
    assert [ "$(cat "$PLUGIN_DATA_ROOT/cron/status")" = "disabled" ]
    assert [ -f "$PLUGIN_DATA_ROOT/cron/disabled_at" ]
}

@test "(dns:cron) shows enabled status when cron job exists" {
    # Setup provider and cron job
    setup_mock_provider
    create_mock_crontab_with_existing_job
    
    # Create cron metadata
    mkdir -p "$PLUGIN_DATA_ROOT/cron"
    echo "enabled" > "$PLUGIN_DATA_ROOT/cron/status"
    echo "0 2 * * *" > "$PLUGIN_DATA_ROOT/cron/schedule"
    echo "dokku dns:sync-all" > "$PLUGIN_DATA_ROOT/cron/command"
    echo "$PLUGIN_DATA_ROOT/cron/sync.log" > "$PLUGIN_DATA_ROOT/cron/log_file"
    echo "2025-08-12 10:00:00" > "$PLUGIN_DATA_ROOT/cron/enabled_at"
    
    # Create a sample log file
    echo "$(date): DNS cron job enabled" > "$PLUGIN_DATA_ROOT/cron/sync.log"
    echo "$(date): DNS sync completed successfully" >> "$PLUGIN_DATA_ROOT/cron/sync.log"
    
    run dns_cron
    assert_success
    assert_output_contains "Status: ✅ ENABLED"
    assert_output_contains "Schedule: 0 2 * * * (Daily at 2:00 AM)"
    assert_output_contains "Command: dokku dns:sync-all"
    assert_output_contains "Enabled At: 2025-08-12 10:00:00"
    assert_output_contains "Recent Log Entries"
    assert_output_contains "DNS sync completed successfully"
}

@test "(dns:cron) shows log information correctly" {
    # Create cron metadata with log file
    mkdir -p "$PLUGIN_DATA_ROOT/cron"
    echo "enabled" > "$PLUGIN_DATA_ROOT/cron/status"
    echo "$PLUGIN_DATA_ROOT/cron/sync.log" > "$PLUGIN_DATA_ROOT/cron/log_file"
    
    # Create log file with multiple entries
    local log_file="$PLUGIN_DATA_ROOT/cron/sync.log"
    for i in {1..15}; do
        echo "$(date): Log entry $i" >> "$log_file"
    done
    
    run dns_cron
    assert_success
    assert_output_contains "Log Entries: 15 lines"
    assert_output_contains "Recent Log Entries (last 10 lines)"
    assert_output_contains "Log entry 15"  # Should show the last entry
    refute_output_contains "Log entry 5"   # Should not show early entries
}

# Helper functions
setup_mock_provider() {
    mkdir -p "$PLUGIN_DATA_ROOT"
    echo "aws" > "$PLUGIN_DATA_ROOT/PROVIDER"
}

cleanup_mock_cron() {
    # Remove any mock crontab
    rm -f "$TEST_TMP_DIR/bin/crontab" >/dev/null 2>&1 || true
    # Clean up any existing cron data
    rm -rf "$PLUGIN_DATA_ROOT/cron" >/dev/null 2>&1 || true
}

create_mock_crontab() {
    # Ensure test bin directory exists
    mkdir -p "$TEST_TMP_DIR/bin"
    
    # Create mock crontab command that simulates empty crontab
    cat > "$TEST_TMP_DIR/bin/crontab" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-l" ]]; then
    # Return empty for list
    exit 1
elif [[ "$1" == "-" ]]; then
    # Accept input for setting crontab
    cat > /dev/null
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$TEST_TMP_DIR/bin/crontab"
}

create_mock_crontab_with_existing_job() {
    # Ensure test bin directory exists  
    mkdir -p "$TEST_TMP_DIR/bin"
    
    # Create mock crontab command that simulates existing DNS cron job
    cat > "$TEST_TMP_DIR/bin/crontab" << 'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-l" ]]; then
    # Return existing cron job
    echo "0 2 * * * dokku dns:sync-all >> /var/lib/dokku/services/dns/cron/sync.log 2>&1 # Dokku DNS auto-sync"
    exit 0
elif [[ "$1" == "-" ]]; then
    # Accept input and simulate removal of DNS job
    local input
    input=$(cat)
    if ! echo "$input" | grep -q "dokku dns:sync-all"; then
        # Job was removed
        return 0
    fi
    exit 0
else
    exit 1
fi
EOF
    chmod +x "$TEST_TMP_DIR/bin/crontab"
}

# Command aliases for easier testing
dns_cron() {
    "$PLUGIN_ROOT/subcommands/cron"
}

dns_cron_enable() {
    "$PLUGIN_ROOT/subcommands/cron-enable"
}

dns_cron_disable() {
    "$PLUGIN_ROOT/subcommands/cron-disable"
}