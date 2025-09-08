#!/usr/bin/env bash

sudo() {
  if [[ "$1" == "-u" && "$2" == "dokku" ]]; then
    shift 2  # Remove -u dokku
    if [[ "$1" == "true" ]]; then
      return 1
    elif [[ "$1" == "crontab" ]]; then
      return 1
    else
      "$@"
    fi
  else
    "$@"
  fi
}
export -f sudo

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

crontab() {
  local mock_crontab_file="${TEST_TMP_DIR:-/tmp}/mock_crontab_state"
  
  case "$1" in
    "-l")
      cat "$mock_crontab_file" 2>/dev/null || echo ""
      ;;
    "-u")
      if [[ "$2" == "dokku" ]]; then
        case "$3" in
          "-l")
            cat "$mock_crontab_file" 2>/dev/null || echo ""
            ;;
          *)
            cat > "$mock_crontab_file"
            ;;
        esac
      fi
      ;;
    *)
      cat > "$mock_crontab_file"
      ;;
  esac
  return 0
}
export -f crontab

if [[ ! -d "/var/lib/dokku" ]] || [[ ! -w "/var/lib/dokku" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/mock_dokku_environment.bash"
else
  export DOKKU_LIB_ROOT="/var/lib/dokku"
  export PATH="$PATH:$DOKKU_LIB_ROOT/plugins/available/dns/subcommands"
fi

CONFIG_PATH="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/config"
if [[ -f "$CONFIG_PATH" ]]; then
  source "$CONFIG_PATH"
elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/config" ]]; then
  source "$(dirname "${BASH_SOURCE[0]}")/config"
else
  echo "Error: Cannot find config file" >&2
  exit 1
fi

if [[ -d "$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")/subcommands" ]]; then
  PLUGIN_ROOT="$(dirname "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)")"
else
  PLUGIN_ROOT="$(dirname "${BASH_SOURCE[0]}")"
fi
export PLUGIN_ROOT
TEST_BIN_DIR="$(dirname "${BASH_SOURCE[0]}")/bin"
export PATH="$TEST_BIN_DIR:$PLUGIN_ROOT/subcommands:$PATH"

if [[ -f "$TEST_BIN_DIR/dokku" ]]; then
  dokku() {
    if [[ -n "$TEST_TMP_DIR" && -f "$TEST_TMP_DIR/bin/dokku" ]]; then
      "$TEST_TMP_DIR/bin/dokku" "$@"
    else
      "$TEST_BIN_DIR/dokku" "$@"
    fi
  }
  export -f dokku
fi


setup_writable_test_bin() {
  if ! touch "$TEST_BIN_DIR/.write_test" 2>/dev/null; then
    if [[ -z "$TEST_TMP_DIR" ]]; then
      TEST_TMP_DIR=$(mktemp -d)
      export TEST_TMP_DIR
    fi
    
    WRITABLE_TEST_BIN="$TEST_TMP_DIR/bin"
    mkdir -p "$WRITABLE_TEST_BIN"
    
    if [[ -d "$TEST_BIN_DIR" ]]; then
      cp -r "$TEST_BIN_DIR"/* "$WRITABLE_TEST_BIN/" 2>/dev/null || true
      chmod +x "$WRITABLE_TEST_BIN"/* 2>/dev/null || true
    fi
    
    export PATH="$WRITABLE_TEST_BIN:$PATH"
    
    echo "$WRITABLE_TEST_BIN"
  else
    rm -f "$TEST_BIN_DIR/.write_test" 2>/dev/null || true
    echo "$TEST_BIN_DIR"
  fi
}

dns_cmd() {
  local subcmd="$1"
  shift
  "$PLUGIN_ROOT/subcommands/$subcmd" "$@"
}

setup_dns_provider() {
  local provider="${1:-aws}"
  return 0
}

cleanup_dns_data() {
  if [[ -d "/var/lib/dokku" ]] && [[ -w "/var/lib/dokku" ]]; then
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

assert_exit_status() {
  # shellcheck disable=SC2154
  assert_equal "$1" "$status"
}

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

assert_output() {
  local expected
  if [ $# -eq 0 ]; then
    expected="$(cat -)"
  else
    expected="$1"
  fi
  # shellcheck disable=SC2154
  assert_equal "$expected" "$output"
}

assert_output_contains() {
  # shellcheck disable=SC2154
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

backup_main_aws_mock() {
  if [[ -f "$TEST_BIN_DIR/aws" ]]; then
    cp "$TEST_BIN_DIR/aws" "$TEST_BIN_DIR/aws.backup" 2>/dev/null || true
    export AWS_MOCK_BACKED_UP=true
  fi
}

restore_main_aws_mock() {
  if [[ "${AWS_MOCK_BACKED_UP:-}" == "true" ]] && [[ -f "$TEST_BIN_DIR/aws.backup" ]]; then
    cp "$TEST_BIN_DIR/aws.backup" "$TEST_BIN_DIR/aws" 2>/dev/null || true
    rm -f "$TEST_BIN_DIR/aws.backup" 2>/dev/null || true
    unset AWS_MOCK_BACKED_UP
  fi
}

create_temporary_aws_mock() {
  local mock_content="$1"
  
  backup_main_aws_mock
  
  local BIN_DIR="$PLUGIN_DATA_ROOT/bin"
  mkdir -p "$BIN_DIR"
  echo "$mock_content" > "$BIN_DIR/aws"
  chmod +x "$BIN_DIR/aws"
  
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    export PATH="$BIN_DIR:$PATH"
  fi
}

set_aws_mock_record_count() {
  local count="${1:-0}"
  local record_prefix="${2:-test-record}"
  
  local control_file="$PLUGIN_DATA_ROOT/aws_mock_control"
  mkdir -p "$PLUGIN_DATA_ROOT"
  
  echo "RECORD_COUNT=$count" > "$control_file"
  echo "RECORD_PREFIX=$record_prefix" >> "$control_file"
  export AWS_MOCK_CONTROL_FILE="$control_file"
}

clear_aws_mock_record_count() {
  local control_file="$PLUGIN_DATA_ROOT/aws_mock_control"
  rm -f "$control_file"
  unset AWS_MOCK_CONTROL_FILE
}
