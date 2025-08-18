#!/usr/bin/env bash
# Override test environment to use temporary directories for unit tests

# Create temporary test directory
TEST_TMP_DIR="${BATS_TMPDIR:-/tmp}/dokku-dns-test-$$"
mkdir -p "$TEST_TMP_DIR"

# Override environment variables to use temp directory
export DOKKU_LIB_ROOT="$TEST_TMP_DIR/dokku"
export PLUGIN_DATA_ROOT="$TEST_TMP_DIR/dokku/services/dns"
export PLUGIN_CONFIG_ROOT="$TEST_TMP_DIR/dokku/config/dns"

# Create necessary directories
mkdir -p "$DOKKU_LIB_ROOT"
mkdir -p "$PLUGIN_DATA_ROOT" 
mkdir -p "$PLUGIN_CONFIG_ROOT"

# Override cleanup function to clean our temp directory
cleanup_dns_data() {
  rm -rf "$PLUGIN_DATA_ROOT" >/dev/null 2>&1 || true
  rm -rf "$PLUGIN_CONFIG_ROOT" >/dev/null 2>&1 || true
}

# Create mock dokku command for testing
create_mock_dokku() {
  local mock_dir="$TEST_TMP_DIR/bin"
  mkdir -p "$mock_dir"
  
  # Create apps tracking file and export path
  export DOKKU_APPS_FILE="$TEST_TMP_DIR/apps_list"
  echo "testapp" > "$DOKKU_APPS_FILE"
  echo "nextcloud" >> "$DOKKU_APPS_FILE"
  
  # Use the existing test bin/dokku if available, otherwise create a basic mock
  local test_bin_dir
  test_bin_dir="$(dirname "${BASH_SOURCE[0]}")/bin"
  if [[ -f "$test_bin_dir/dokku" ]]; then
    # Copy our DNS-aware test mock instead of creating a basic one
    cp "$test_bin_dir/dokku" "$mock_dir/dokku"
    chmod +x "$mock_dir/dokku"
  else
    # Fallback basic mock for environments without our test mock
    cat > "$mock_dir/dokku" << EOF
#!/usr/bin/env bash
# Mock dokku command for testing

case "\$1" in
    "apps:create")
        echo "Creating app: \$2"
        echo "\$2" >> "\$DOKKU_APPS_FILE"
        ;;
    "domains:add")
        echo "Adding domain \$3 to app \$2"
        # Store domain for this app  
        DOMAINS_DIR="\$(dirname "\$DOKKU_APPS_FILE")/domains"
        mkdir -p "\$DOMAINS_DIR"
        echo "\$3" >> "\$DOMAINS_DIR/\$2"
        ;;
    "domains:report")
        # Return domains for specific app if available
        APP_ARG="\$2"
        DOMAINS_DIR="\$(dirname "\$DOKKU_APPS_FILE")/domains"
        if [[ -f "\$DOMAINS_DIR/\$APP_ARG" ]]; then
            tr '\\n' ' ' < "\$DOMAINS_DIR/\$APP_ARG"
            echo
        else
            # No domains for this app
            echo ""
        fi
        ;;
    "apps:list")
        cat "\$DOKKU_APPS_FILE" 2>/dev/null || echo "testapp"
        ;;
    *)
        echo "Mock dokku: \$*"
        ;;
esac
EOF
    chmod +x "$mock_dir/dokku"
  fi
  
  # Put mock dokku at the very beginning of PATH
  export PATH="$mock_dir:$PATH"
}

# Initialize mock environment
create_mock_dokku

# Cleanup function for end of tests
cleanup_test_env() {
    rm -rf "$TEST_TMP_DIR" >/dev/null 2>&1 || true
}

# Register cleanup
trap cleanup_test_env EXIT