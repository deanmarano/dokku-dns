#!/usr/bin/env bash

# Mock sudo for unit tests to avoid authentication prompts and force fallback to regular crontab
sudo() {
  if [[ "$1" == "-u" && "$2" == "dokku" ]]; then
    shift 2  # Remove -u dokku
    if [[ "$1" == "true" ]]; then
      # Fail permission test to force fallback to regular crontab
      return 1
    elif [[ "$1" == "crontab" ]]; then
      # Fail crontab test to force fallback to regular crontab
      return 1
    else
      # For other dokku user commands, execute directly
      "$@"
    fi
  else
    # For other sudo commands, execute directly
    "$@"
  fi
}
export -f sudo

# Mock id command to simulate dokku user existence
id() {
  if [[ "$1" == "-u" && "$2" == "dokku" ]]; then
    echo "1001"  # Return fake dokku UID
  elif [[ "$1" == "-un" ]]; then
    echo "$USER"  # Return current user
  else
    command id "$@"
  fi
}
export -f id

# Mock crontab command to avoid sudo issues in tests
crontab() {
  local mock_crontab_file="${TEST_TMP_DIR:-/tmp}/mock_crontab_state"
  
  # Handle different crontab operations
  case "$1" in
    "-l")
      # List crontab - return mock state
      cat "$mock_crontab_file" 2>/dev/null || echo ""
      ;;
    "-u")
      # Handle -u user operations
      if [[ "$2" == "dokku" ]]; then
        case "$3" in
          "-l")
            # List dokku user crontab
            cat "$mock_crontab_file" 2>/dev/null || echo ""
            ;;
          *)
            # Install from stdin for dokku user
            cat > "$mock_crontab_file"
            ;;
        esac
      fi
      ;;
    *)
      # Install from stdin
      cat > "$mock_crontab_file"
      ;;
  esac
  return 0
}
export -f crontab

# NOTE: dokku mock function is defined later in this file (after TEST_BIN_DIR setup)
# to ensure proper precedence with script-based mocks

# Load test environment overrides for CI/local testing
if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/mock_dokku_environment.bash"
else
  # Use real Dokku environment if available
  export DOKKU_LIB_ROOT="/var/lib/dokku"
  export PATH="$PATH:$DOKKU_LIB_ROOT/plugins/available/dns/subcommands"
fi

# Try to source config from parent directory first, then current directory (for Docker tests)
CONFIG_PATH="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/config"
if [[ -f "$CONFIG_PATH" ]]; then
  source "$CONFIG_PATH"
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/config" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/config"
else
  echo "Error: Cannot find config file" >&2
  exit 1
fi

# Add subcommands and test bin to PATH for testing (prioritize test bin)
# Set PLUGIN_ROOT for both normal and Docker test environments
if [[ -d "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/subcommands" ]]; then
  PLUGIN_ROOT="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
else
  # Docker test environment - subcommands are in current directory
  PLUGIN_ROOT="$(dirname "${BASH_SOURCE[0]}")"
fi
export PLUGIN_ROOT
TEST_BIN_DIR="$(dirname "${BASH_SOURCE[0]}")/bin"
export PATH="$TEST_BIN_DIR:$PLUGIN_ROOT/subcommands:$PATH"

# Ensure our test dokku takes precedence over system dokku
if [[ -f "$TEST_BIN_DIR/dokku" ]]; then
  # shellcheck disable=SC2139
  alias dokku="$TEST_BIN_DIR/dokku"
  # Also create a function override that works in subshells (for BATS)
  # This function will dynamically choose the correct mock dokku based on environment
  dokku() {
    local mock_config_file="${TEST_TMP_DIR:-/tmp}/mock_dokku_config"

    # Only mock if running in unit test mode (no real Dokku available)
    if [[ -d "/var/lib/dokku" ]] && [[ -w "/var/lib/dokku" ]]; then
      # Use real dokku if available
      command dokku "$@"
      return $?
    fi

    # Handle dokku config commands
    if [[ "$1" == "config:get" ]]; then
      local scope="$2"
      local key="$3"

      if [[ "$scope" == "--global" ]]; then
        # Read from mock config file
        if [[ -f "$mock_config_file" ]]; then
          grep "^${key}=" "$mock_config_file" 2>/dev/null | cut -d= -f2-
        fi
      fi
      return 0
    elif [[ "$1" == "config:set" ]]; then
      local scope="$2"
      shift 2

      if [[ "$scope" == "--global" ]]; then
        # Write to mock config file
        mkdir -p "$(dirname "$mock_config_file")"
        touch "$mock_config_file"

        # Process key=value pairs
        for arg in "$@"; do
          if [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"

            # Remove existing key if present
            if [[ -f "$mock_config_file" ]]; then
              grep -v "^${key}=" "$mock_config_file" > "${mock_config_file}.tmp" 2>/dev/null || touch "${mock_config_file}.tmp"
              mv "${mock_config_file}.tmp" "$mock_config_file"
            fi

            # Add new key=value
            echo "${key}=${value}" >> "$mock_config_file"
          fi
        done
      fi
      return 0
    elif [[ "$1" == "config:unset" ]]; then
      local scope="$2"
      shift 2

      if [[ "$scope" == "--global" ]]; then
        # Remove keys from mock config file
        if [[ -f "$mock_config_file" ]]; then
          for key in "$@"; do
            grep -v "^${key}=" "$mock_config_file" > "${mock_config_file}.tmp" 2>/dev/null || touch "${mock_config_file}.tmp"
            mv "${mock_config_file}.tmp" "$mock_config_file"
          done
        fi
      fi
      return 0
    else
      # For other dokku commands, use the script-based mocks
      # If we're in a mock environment, use the temporary mock dokku
      if [[ -n "$TEST_TMP_DIR" && -f "$TEST_TMP_DIR/bin/dokku" ]]; then
        "$TEST_TMP_DIR/bin/dokku" "$@"
      else
        "$TEST_BIN_DIR/dokku" "$@"
      fi
    fi
  }
  export -f dokku
fi

# DNS plugin test helper functions

# Ensure we have a writable directory for creating mock scripts
setup_writable_test_bin() {
  # Check if TEST_BIN_DIR is writable
  if ! touch "$TEST_BIN_DIR/.write_test" 2>/dev/null; then
    # Create a writable temporary directory
    if [[ -z "$TEST_TMP_DIR" ]]; then
      TEST_TMP_DIR=$(mktemp -d)
      export TEST_TMP_DIR
    fi
    
    WRITABLE_TEST_BIN="$TEST_TMP_DIR/bin"
    mkdir -p "$WRITABLE_TEST_BIN"
    
    # Copy existing scripts to writable location
    if [[ -d "$TEST_BIN_DIR" ]]; then
      cp -r "$TEST_BIN_DIR"/* "$WRITABLE_TEST_BIN/" 2>/dev/null || true
      chmod +x "$WRITABLE_TEST_BIN"/* 2>/dev/null || true
    fi
    
    # Update PATH to use writable bin directory
    export PATH="$WRITABLE_TEST_BIN:$PATH"
    
    # Return the writable directory path
    echo "$WRITABLE_TEST_BIN"
  else
    # Clean up write test file
    rm -f "$TEST_BIN_DIR/.write_test" 2>/dev/null || true
    echo "$TEST_BIN_DIR"
  fi
}

# Function to call DNS subcommands directly (for testing)
dns_cmd() {
  local subcmd="$1"
  shift
  "$PLUGIN_ROOT/subcommands/$subcmd" "$@"
}

setup_dns_provider() {
  local provider="${1:-aws}"
  # Since global provider concept is removed, this function is now a no-op
  # AWS is always the provider - no setup needed
  return 0
}

cleanup_dns_data() {
  # Clean up all DNS data including cron jobs
  if [[ -d "/var/lib/dokku" ]] && [[ -w "/var/lib/dokku" ]]; then
    # Clean up app-specific data and cron data
    find "$PLUGIN_DATA_ROOT" -name "LINKS" -delete 2>/dev/null || true
    find "$PLUGIN_DATA_ROOT" -maxdepth 1 -type d -name "*-*" -exec rm -rf {} + 2>/dev/null || true
    rm -rf "$PLUGIN_DATA_ROOT/cron" 2>/dev/null || true
  else
    rm -rf "$PLUGIN_DATA_ROOT" >/dev/null 2>&1 || true
  fi
}

create_test_app() {
  local app_name="$1"
  dokku apps:create "$app_name" >/dev/null 2>&1 || true
}

add_test_domains() {
  local app_name="$1"
  shift
  local domains=("$@")
  
  for domain in "${domains[@]}"; do
    dokku domains:add "$app_name" "$domain" >/dev/null 2>&1 || true
  done
}

cleanup_test_app() {
  local app_name="$1"
  dokku apps:destroy "$app_name" --force >/dev/null 2>&1 || true
}

flunk() {
  {
    if [ "$#" -eq 0 ]; then
      cat -
    else
      echo "$*"
    fi
  }
  return 1
}

assert_equal() {
  if [ "$1" != "$2" ]; then
    {
      echo "expected: $1"
      echo "actual:   $2"
    } | flunk
  fi
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
assert_exit_status() {
  assert_equal "$1" "$status"
}

# ShellCheck doesn't know about $status from Bats
# shellcheck disable=SC2154
# shellcheck disable=SC2120
assert_success() {
  if [ "$status" -ne 0 ]; then
    flunk "command failed with exit status $status"
  elif [ "$#" -gt 0 ]; then
    assert_output "$1"
  fi
}

assert_failure() {
  if [[ "$status" -eq 0 ]]; then
    flunk "expected failed exit status"
  elif [[ "$#" -gt 0 ]]; then
    assert_output "$1"
  fi
}

assert_exists() {
  if [ ! -f "$1" ]; then
    flunk "expected file to exist: $1"
  fi
}

assert_contains() {
  if [[ "$1" != *"$2"* ]]; then
    flunk "expected $2 to be in: $1"
  fi
}

# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output() {
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="$1"
  fi
  assert_equal "$expected" "$output"
}

# ShellCheck doesn't know about $output from Bats
# shellcheck disable=SC2154
assert_output_contains() {
  local input="$output"
  local expected="$1"
  local count="${2:-1}"
  local found=0
  until [ "${input/$expected/}" = "$input" ]; do
    input="${input/$expected/}"
    found=$((found + 1))
  done
  assert_equal "$count" "$found"
}

# File assertion helpers
assert_file_exists() {
  local file="$1"
  [[ -f "$file" ]] || flunk "Expected file to exist: $file"
}

assert_file_not_exists() {
  local file="$1"
  [[ ! -f "$file" ]] || flunk "Expected file to not exist: $file"
}

assert_file_executable() {
  local file="$1"
  [[ -x "$file" ]] || flunk "Expected file to be executable: $file"
}

assert_line_in_file() {
  local line="$1"
  local file="$2"
  grep -q "^$line$" "$file" || flunk "Expected line '$line' to be in file: $file"
}

refute_line_in_file() {
  local line="$1"
  local file="$2"
  ! grep -q "^$line$" "$file" || flunk "Expected line '$line' to NOT be in file: $file"
}

# AWS mock backup and restore helpers
backup_main_aws_mock() {
  # Backup the main AWS mock if it exists
  if [[ -f "$TEST_BIN_DIR/aws" ]]; then
    cp "$TEST_BIN_DIR/aws" "$TEST_BIN_DIR/aws.backup" 2>/dev/null || true
    export AWS_MOCK_BACKED_UP=true
  fi
}

restore_main_aws_mock() {
  # Restore the main AWS mock if we backed it up
  if [[ "${AWS_MOCK_BACKED_UP:-}" == "true" ]] && [[ -f "$TEST_BIN_DIR/aws.backup" ]]; then
    cp "$TEST_BIN_DIR/aws.backup" "$TEST_BIN_DIR/aws" 2>/dev/null || true
    rm -f "$TEST_BIN_DIR/aws.backup" 2>/dev/null || true
    unset AWS_MOCK_BACKED_UP
  fi
}

# Create a temporary AWS mock and ensure it gets restored
# Usage: create_temporary_aws_mock "mock content here"
create_temporary_aws_mock() {
  local mock_content="$1"
  
  # Backup the current main mock
  backup_main_aws_mock
  
  # Create the temporary mock
  local BIN_DIR="$PLUGIN_DATA_ROOT/bin"
  mkdir -p "$BIN_DIR"
  echo "$mock_content" > "$BIN_DIR/aws"
  chmod +x "$BIN_DIR/aws"
  
  # Add to PATH if not already there
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:$PATH"
  fi
}

# Set the number of DNS records the AWS mock should return
# Usage: set_aws_mock_record_count <count> [record_prefix]
set_aws_mock_record_count() {
  local count="${1:-0}"
  local record_prefix="${2:-test-record}"
  
  # Create a control file that the AWS mock can read
  local control_file="$PLUGIN_DATA_ROOT/aws_mock_control"
  mkdir -p "$PLUGIN_DATA_ROOT"
  
  echo "RECORD_COUNT=$count" > "$control_file"
  echo "RECORD_PREFIX=$record_prefix" >> "$control_file"
  export AWS_MOCK_CONTROL_FILE="$control_file"
}

# Clear AWS mock record count (use default behavior)
clear_aws_mock_record_count() {
  local control_file="$PLUGIN_DATA_ROOT/aws_mock_control"
  rm -f "$control_file"
  unset AWS_MOCK_CONTROL_FILE
}
