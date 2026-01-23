#!/usr/bin/env bats
load test_helper

# Tests for dns:version command

@test "(dns:version) shows plugin version" {
  run dns_cmd version
  [[ "$output" == *"dokku-dns plugin version"* ]]
}

@test "(dns:version) shows version number" {
  run dns_cmd version
  # Should show a version string
  [[ "$output" == *"version:"* ]] || [[ "$output" == *"version "* ]]
}

@test "(dns:version) command runs without crashing" {
  run dns_cmd version
  # Should show plugin version at minimum
  [[ "$output" == *"dokku-dns"* ]]
}
