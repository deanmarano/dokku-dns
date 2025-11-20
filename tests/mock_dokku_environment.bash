#!/usr/bin/env bash
# Override test environment to use temporary directories for unit tests

# Create temporary test directory
TEST_TMP_DIR="${BATS_TMPDIR:-/tmp}/dokku-dns-test-$$"
export TEST_TMP_DIR
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
    "config:get")
        # Mock dokku config:get for testing
        scope="\$2"
        key="\$3"
        mock_config_file="\${TEST_TMP_DIR:-/tmp}/mock_dokku_config"

        if [[ "\$scope" == "--global" && -f "\$mock_config_file" ]]; then
            grep "^\${key}=" "\$mock_config_file" 2>/dev/null | cut -d= -f2-
        fi
        ;;
    "config:set")
        # Mock dokku config:set for testing
        scope="\$2"
        shift 2
        mock_config_file="\${TEST_TMP_DIR:-/tmp}/mock_dokku_config"

        if [[ "\$scope" == "--global" ]]; then
            mkdir -p "\$(dirname "\$mock_config_file")"
            touch "\$mock_config_file"

            for arg in "\$@"; do
                if [[ "\$arg" =~ ^([^=]+)=(.*)$ ]]; then
                    key="\${BASH_REMATCH[1]}"
                    value="\${BASH_REMATCH[2]}"

                    # Remove existing key
                    if [[ -f "\$mock_config_file" ]]; then
                        grep -v "^\${key}=" "\$mock_config_file" > "\${mock_config_file}.tmp" 2>/dev/null || touch "\${mock_config_file}.tmp"
                        mv "\${mock_config_file}.tmp" "\$mock_config_file"
                    fi

                    # Add new key=value
                    echo "\${key}=\${value}" >> "\$mock_config_file"
                fi
            done
        fi
        ;;
    "config:unset")
        # Mock dokku config:unset for testing
        scope="\$2"
        shift 2
        mock_config_file="\${TEST_TMP_DIR:-/tmp}/mock_dokku_config"

        if [[ "\$scope" == "--global" && -f "\$mock_config_file" ]]; then
            for key in "\$@"; do
                grep -v "^\${key}=" "\$mock_config_file" > "\${mock_config_file}.tmp" 2>/dev/null || touch "\${mock_config_file}.tmp"
                mv "\${mock_config_file}.tmp" "\$mock_config_file"
            done
        fi
        ;;
    *)
        # Silently ignore unknown commands in tests
        :
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