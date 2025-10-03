#!/usr/bin/env bats

load test_helper

setup() {
  # Create temp directory for test isolation
  TEST_TMP_DIR=$(mktemp -d)
  export TEST_TMP_DIR
  export PLUGIN_DATA_ROOT="$TEST_TMP_DIR/dns-data"
  mkdir -p "$PLUGIN_DATA_ROOT"
  mkdir -p "$TEST_TMP_DIR/bin"

  # Setup writable test bin
  setup_writable_test_bin >/dev/null
}

teardown() {
  rm -rf "$TEST_TMP_DIR"
}

# Helper to create mock dokku command
create_mock_dokku() {
  local global_vhost="$1"
  cat >"$TEST_TMP_DIR/bin/dokku" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "domains:report" && "\$2" == "--global" ]]; then
  echo "$global_vhost"
elif [[ "\$1" == "dns:apps:enable" ]]; then
  # Simulate successful enable by creating app directory
  mkdir -p "$PLUGIN_DATA_ROOT/\$2"
  echo "\$3" > "$PLUGIN_DATA_ROOT/\$2/DOMAINS"
  exit 0
elif [[ "\$1" == "dns:sync" ]]; then
  # Simulate successful sync
  exit 0
fi
EOF
  chmod +x "$TEST_TMP_DIR/bin/dokku"
  export PATH="$TEST_TMP_DIR/bin:$PATH"
}

@test "(post-create) creates DNS record when zone is enabled" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable zone
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku that provides global vhost
  create_mock_dokku "example.com"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "DNS: Record for 'myapp.example.com' created successfully"

  # Verify app directory was created
  assert_file_exists "$PLUGIN_DATA_ROOT/myapp/DOMAINS"
}

@test "(post-create) skips when zone is not enabled" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Do NOT enable the zone
  echo "" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku
  create_mock_dokku "example.com"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "not in an enabled zone"
  assert_output_contains "Skipping automatic DNS setup"

  # Verify app directory was NOT created
  [[ ! -d "$PLUGIN_DATA_ROOT/myapp" ]]
}

@test "(post-create) skips when no global vhost configured" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Create mock dokku with no global vhost
  create_mock_dokku ""

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "No global vhost configured"

  # Verify app directory was NOT created
  [[ ! -d "$PLUGIN_DATA_ROOT/myapp" ]]
}

@test "(post-create) skips when app already managed" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable zone
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku
  create_mock_dokku "example.com"

  # Simulate app already being managed
  echo "myapp" >"$PLUGIN_DATA_ROOT/LINKS"
  mkdir -p "$PLUGIN_DATA_ROOT/myapp"
  echo "myapp.example.com" >"$PLUGIN_DATA_ROOT/myapp/DOMAINS"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "already managed by DNS"
}

@test "(post-create) passes predicted domain to dns:apps:enable" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable zone
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku that captures arguments
  cat >"$TEST_TMP_DIR/bin/dokku" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "domains:report" && "$2" == "--global" ]]; then
  echo "example.com"
elif [[ "$1" == "dns:apps:enable" ]]; then
  # Capture the arguments to verify predicted domain was passed
  echo "dns:apps:enable called with: $2 $3" >> "$TEST_TMP_DIR/dokku-calls"
  mkdir -p "$PLUGIN_DATA_ROOT/$2"
  echo "$3" > "$PLUGIN_DATA_ROOT/$2/DOMAINS"
  exit 0
elif [[ "$1" == "dns:sync" ]]; then
  exit 0
fi
EOF
  chmod +x "$TEST_TMP_DIR/bin/dokku"
  export PATH="$TEST_TMP_DIR/bin:$PATH"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success

  # Verify predicted domain was passed
  assert_file_exists "$TEST_TMP_DIR/dokku-calls"
  grep -q "dns:apps:enable called with: myapp myapp.example.com" "$TEST_TMP_DIR/dokku-calls"
}

@test "(post-create) handles dns:apps:enable failure gracefully" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable zone
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku where dns:apps:enable fails
  cat >"$TEST_TMP_DIR/bin/dokku" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "domains:report" && "$2" == "--global" ]]; then
  echo "example.com"
elif [[ "$1" == "dns:apps:enable" ]]; then
  # Fail without creating directory
  exit 1
elif [[ "$1" == "dns:sync" ]]; then
  exit 0
fi
EOF
  chmod +x "$TEST_TMP_DIR/bin/dokku"
  export PATH="$TEST_TMP_DIR/bin:$PATH"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "Failed to enable app 'myapp' for DNS management"
}

@test "(post-create) handles dns:sync failure gracefully" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable zone
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku where dns:sync fails
  cat >"$TEST_TMP_DIR/bin/dokku" <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "domains:report" && "$2" == "--global" ]]; then
  echo "example.com"
elif [[ "$1" == "dns:apps:enable" ]]; then
  mkdir -p "$PLUGIN_DATA_ROOT/$2"
  echo "$3" > "$PLUGIN_DATA_ROOT/$2/DOMAINS"
  exit 0
elif [[ "$1" == "dns:sync" ]]; then
  # Fail sync
  exit 1
fi
EOF
  chmod +x "$TEST_TMP_DIR/bin/dokku"
  export PATH="$TEST_TMP_DIR/bin:$PATH"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "Failed to create DNS record automatically"
  assert_output_contains "Manual sync with: dokku dns:sync myapp"
}

@test "(post-create) uses correct zone enablement check" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable only subdomain zone, not the one we're testing
  echo "other.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku
  create_mock_dokku "example.com"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success
  assert_output_contains "not in an enabled zone"

  # Verify app directory was NOT created
  [[ ! -d "$PLUGIN_DATA_ROOT/myapp" ]]
}

@test "(post-create) output is clean and concise" {
  # Enable triggers
  touch "$PLUGIN_DATA_ROOT/TRIGGERS_ENABLED"

  # Enable zone
  echo "example.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  # Create mock dokku
  create_mock_dokku "example.com"

  # Run post-create trigger
  run "$PLUGIN_ROOT/post-create" "myapp"

  assert_success

  # Verify verbose messages are NOT present
  refute_output "Checking if app"
  refute_output "Predicted default domain:"
  refute_output "Predicted domain is in an enabled zone"
  refute_output "App 'myapp' enabled for DNS management"
  refute_output "Syncing DNS records"

  # Only success message should be present
  assert_output_contains "DNS: Record for 'myapp.example.com' created successfully"
}
