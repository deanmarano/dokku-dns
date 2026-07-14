#!/usr/bin/env bats

load test_helper

# Regression tests for the vhost-rename orphan bug: the DOMAINS file was written once
# and never reconciled, so renaming a vhost left the old name tracked and synced
# forever while the real one went unmanaged and silently stale.

setup() {
  cleanup_dns_data
  mkdir -p "$PLUGIN_DATA_ROOT"
  echo "test1.com" >"$PLUGIN_DATA_ROOT/ENABLED_ZONES"

  create_test_app reconcile-app
  add_test_domains reconcile-app old.test1.com
  dokku "$PLUGIN_COMMAND_PREFIX:apps:enable" reconcile-app >/dev/null 2>&1 || true
}

teardown() {
  cleanup_dns_data
}

# Rewrite what dokku reports as the app's live vhosts, simulating a rename.
set_live_vhosts() {
  local app="$1"
  shift
  local domains_dir
  domains_dir="$(dirname "$DOKKU_APPS_FILE")/domains"
  mkdir -p "$domains_dir"
  printf '%s\n' "$@" >"$domains_dir/$app"
}

@test "(reconcile) renamed vhost replaces the orphaned name in DOMAINS" {
  echo "old.test1.com" >"$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  set_live_vhosts reconcile-app new.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" reconcile-app

  run cat "$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  [[ "$output" == *"new.test1.com"* ]]
  [[ "$output" != *"old.test1.com"* ]]
}

@test "(reconcile) reports the untracked and newly tracked domains" {
  echo "old.test1.com" >"$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  set_live_vhosts reconcile-app new.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" reconcile-app
  [[ "$output" == *"old.test1.com"* ]]
  [[ "$output" == *"untracking"* ]]
  [[ "$output" == *"new.test1.com"* ]]
  [[ "$output" == *"tracking"* ]]
}

@test "(reconcile) picks up a vhost added while triggers were disabled" {
  echo "old.test1.com" >"$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  set_live_vhosts reconcile-app old.test1.com extra.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" reconcile-app

  run cat "$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  [[ "$output" == *"old.test1.com"* ]]
  [[ "$output" == *"extra.test1.com"* ]]
}

@test "(reconcile) a failed vhost lookup does not wipe tracked domains" {
  # An empty report means vhosts disabled / app gone / dokku errored. We cannot tell
  # those apart, so DOMAINS must be left alone rather than treated as "all removed".
  echo "old.test1.com" >"$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  set_live_vhosts reconcile-app ""

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" reconcile-app

  run cat "$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  [[ "$output" == *"old.test1.com"* ]]
}

@test "(reconcile) unchanged vhosts leave DOMAINS untouched" {
  echo "old.test1.com" >"$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  set_live_vhosts reconcile-app old.test1.com

  run dokku "$PLUGIN_COMMAND_PREFIX:apps:sync" reconcile-app
  [[ "$output" != *"untracking"* ]]
  [[ "$output" != *"new vhost"* ]]

  run cat "$PLUGIN_DATA_ROOT/reconcile-app/DOMAINS"
  [[ "$output" == *"old.test1.com"* ]]
}
