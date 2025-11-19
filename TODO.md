# TODO

The DNS plugin is in progress! Many core features have been implemented and tested. See [DONE.md](./DONE.md) for completed work.


### Phase 28: Display and Reporting Fixes (Pre-Release)

**Objective:** Fix inconsistent zone detection in status displays and reduce excessive output verbosity.

- [ ] **Fix Zone Lookup in Report/Status Commands**
  - [ ] Fix zone lookup in report subcommand to use same logic as apps:enable
  - [ ] Update Domain Status Table to reflect actual zone detection results
  - [ ] Ensure consistency between "checking" phase and status table
  - [ ] Show actual zone ID or provider in table when zone is found
  - [ ] Clarify difference between "zone exists" vs "zone enabled for auto-discovery"
  - **Problem:** `dns:report` shows "No hosted zone" even when zones exist and are enabled
  - **Location:** `subcommands/report`, `functions:dns_add_app_domains()` status table
  - **Examples:**
    - `dns:report website` shows "No hosted zone" for dean.is (zone ZZ36BKMR6SB53 exists)
    - `dns:apps:enable` shows "✓ dean.is can be managed" but table shows "⚠️ No (no hosted zone)"

- [ ] **Reduce provider:verify Output Verbosity**
  - [ ] Reduce excessive verbosity (multiple heading levels, redundant messages)
  - [ ] Condense zone listing (don't show every zone detail in table)
  - [ ] Remove redundant "checking" messages
  - [ ] Show summary counts instead of full credential detection lists
  - [ ] Add --verbose flag for detailed output if needed
  - **Problem:** `dns:providers:verify` output is excessively verbose
  - **Reference:** See `test-output-examples/provider-verify-output.txt`


### Phase 29: Trigger System Improvements (Pre-Release)

**Objective:** Fix post-create trigger failing to detect auto-added domains from global vhost.

- [ ] **Fix Post-Create Trigger Domain Detection**
  - [ ] post-create trigger says "No domains configured" but domain exists
  - [ ] Trigger doesn't detect auto-added domain from global vhost
  - [ ] Fix is_domain_in_enabled_zone function or post-create timing
  - [ ] Test: my-test-app.deanoftech.com should be detected in enabled deanoftech.com zone
  - **Problem:** Trigger runs before domain is fully configured
  - **Reference:** See `test-output-examples/app-create-trigger-fail.txt`


### Phase 30: Zone Management UX Improvements (Pre-Release)

**Objective:** Improve user experience for zone management with better output and new sync command.

- [ ] **Improve Zone Enable Output**
  - [ ] Output copy-pastable commands when enabling a zone
  - [ ] Show `dokku dns:apps:enable <app>` commands with domain as comment
  - [ ] Format: `dokku dns:apps:enable myapp  # example.com`
  - [ ] Group by app to avoid duplicate commands
  - **Goal:** Make it easier for users to enable apps after enabling zones

- [ ] **Add zones:sync Command**
  - [ ] Create `dns:zones:sync [zone]` subcommand
  - [ ] Sync all apps/domains within a specific zone
  - [ ] If zone parameter omitted, sync all enabled zones
  - [ ] Show progress per domain within the zone
  - **Goal:** Bulk sync operations at the zone level


### Phase 30a: Provider Interface Extension - Record Listing (Pre-Release)

**Objective:** Extend provider interface to support listing all DNS records in a zone, enabling DNS cleanup features.

- [ ] **Extend Provider Interface**
  - [ ] Add `provider_list_records(zone_id)` to providers/INTERFACE.md
  - [ ] Define input/output format for record listing
  - [ ] Specify return format: "name type value ttl" one per line
  - [ ] Document error handling and empty zone behavior
  - **Location:** `providers/INTERFACE.md`

- [ ] **Implement for All Providers**
  - [ ] Implement `provider_list_records()` in providers/aws/provider.sh
  - [ ] Implement `provider_list_records()` in providers/cloudflare/provider.sh
  - [ ] Implement `provider_list_records()` in providers/digitalocean/provider.sh
  - [ ] Add tests for each provider implementation
  - **Goal:** Consistent record listing across all DNS providers

- [ ] **Re-enable DNS Cleanup Candidates Feature**
  - [ ] Remove `continue` bypass in subcommands/report:548
  - [ ] Uncomment record listing code in get_records_to_be_deleted()
  - [ ] Replace `aws route53 list-resource-record-sets` with `provider_list_records()`
  - [ ] Update to use multi-provider routing
  - [ ] Test cleanup detection with all providers
  - **Location:** `subcommands/report` get_records_to_be_deleted() function
  - **Reference:** Currently disabled at lines 543-558


### Phase 31: Pre-Release Testing & Validation

- [ ] **Create Testing Documentation**
  - [ ] Create TESTING.md with manual test procedures for all providers
  - [ ] Document CRUD operations test checklist for AWS Route53
  - [ ] Document CRUD operations test checklist for Cloudflare
  - [ ] Document CRUD operations test checklist for DigitalOcean
  - [ ] Include test result logging template with pass/fail criteria
  - [ ] Document common troubleshooting scenarios and solutions

- [ ] **Provider Integration Testing**
  - [ ] Execute AWS Route53 CRUD operations on production server
  - [ ] Execute Cloudflare CRUD operations on production server
  - [ ] Execute DigitalOcean CRUD operations on production server
  - [ ] Test multi-provider zone routing (domains in different providers)
  - [ ] Validate provider failover and error handling

- [ ] **Installation & Deployment Testing**
  - [ ] Test plugin installation from GitHub on fresh Dokku instance
  - [ ] Validate provider setup workflow for each provider
  - [ ] Test automatic zone discovery after provider configuration
  - [ ] Verify trigger system integration with app lifecycle events
  - [ ] Test sync-all command with multiple apps and providers


### Phase 32: 1.0 Release

- [ ] **GitHub Release Infrastructure**
  - [ ] Create semantic version tagging strategy (v1.0.0)
  - [ ] Set up release branch protection and approval workflows

- [ ] **Release Artifacts**
  - [ ] Generate documentation bundle with all guides and references
  - [ ] Create installation scripts for multiple platforms

- [ ] **Post-Release Validation**
  - [ ] Verify GitHub release visibility and downloads
  - [ ] Validate documentation link accessibility
  - [ ] Coordinate community notifications and announcements
  - [ ] Prepare issue tracking and support channels
  - [ ] Set up performance monitoring and error tracking


### Phase 33: Community & Support (Post-Release)

- [ ] **Community Announcements**
  - [ ] Post to Dokku community forum
  - [ ] Create GitHub repository announcement and pinned issue
  - [ ] Execute social media announcement strategy
  - [ ] Publish technical blog post highlighting key features

- [ ] **Support Infrastructure**
  - [ ] Create issue templates for bug reports and feature requests
  - [ ] Create discussion templates for community support
  - [ ] Write contributing guidelines for community contributors
  - [ ] Establish code of conduct and community standards

- [ ] **Post-Release Maintenance Planning**
  - [ ] Define patch release strategy and versioning scheme
  - [ ] Set up community feedback collection and analysis process
  - [ ] Create bug triage and priority classification system
  - [ ] Design feature request evaluation and roadmap integration


### Phase 34: Code Quality - Medium Priority Cleanup (Post-1.0)

- [ ] **Extract Duplicate Provider Code**
  - [ ] Create `apply_dns_record` helper function in adapter.sh
  - [ ] Replace duplicated code in adapter.sh:204-210 and 221-227
  - [ ] Ensure error messages are preserved (not sent to /dev/null)
  - [ ] Add proper error logging for debugging

- [ ] **Add Comprehensive Input Validation**
  - [ ] Create `validate_dns_domain` helper function for RFC 1035 compliance
  - [ ] Add domain validation to all subcommands that accept domains
  - [ ] Add TTL validation to zones:ttl subcommand (currently missing)
  - [ ] Add TTL validation to ttl subcommand (currently missing)
  - [ ] Ensure consistent validation across all entry points

- [ ] **Define Constants in Config**
  - [ ] Add DNS_DEFAULT_TTL=300 to config file
  - [ ] Add DNS_MIN_TTL=60 to config file
  - [ ] Add DNS_MAX_TTL=86400 to config file
  - [ ] Replace hardcoded "300" in functions:981 with constant
  - [ ] Replace hardcoded TTL values in adapter.sh:202, 218 with constants
  - [ ] Update all TTL validation to use constants

- [ ] **Remove MULTI_PROVIDER_MODE Flag**
  - [ ] Remove MULTI_PROVIDER_MODE environment variable (always true, legacy code)
  - [ ] Remove all `if [[ "${MULTI_PROVIDER_MODE:-false}" == "true" ]]` conditionals in adapter.sh
  - [ ] Always call multi_* functions (multi_get_zone_id, multi_get_record, etc.)
  - [ ] Delete dead code branches that call provider_* directly (lines 147-155 in adapter.sh)
  - [ ] Update init_provider_system to always use multi-provider routing
  - [ ] Remove "Multi-provider mode activated" messages (it's the only mode)

- [ ] **Remove All Non-Multi-Provider Code**
  - [ ] **Replace direct `provider_get_zone_id` calls with `multi_get_zone_id` in application code**
    - [ ] **functions:406** - Checking if skipped domain has a zone (in skipped domains warning section)
    - [ ] **functions:800** - Getting zone ID for DNS record operations (in DNS sync logic)
    - **Note:** `provider_get_zone_id` is the provider interface (each provider implements it)
    - **Note:** `multi_get_zone_id` is the multi-provider router (application code should use this)
    - **Architecture:** Application → `multi_get_zone_id` → finds provider → `provider_get_zone_id`
  - [ ] Search codebase for `dns_provider_` function calls and replace with `multi_` equivalents
  - [ ] Remove any remaining direct provider-specific function calls (aws_*, cloudflare_*, etc.)
  - [ ] Ensure all subcommands source multi-provider.sh for zone lookup
  - [ ] Replace `dns_provider_aws_get_hosted_zone_id` with `multi_get_zone_id` everywhere
  - [ ] Replace `dns_provider_aws_*` calls with appropriate multi-provider adapter functions
  - [ ] Remove unused provider-specific helper functions that are duplicates of multi-provider equivalents
  - [ ] Audit all hooks, subcommands, and functions for legacy provider patterns


### Phase 35: Code Quality - Low Priority Polish (Post-1.0)

- [ ] **Reduce Logging Verbosity**
  - [ ] Extract logging from functions:347-397 (dns_add_app_domains)
  - [ ] Create `log_domain_check` helper for conditional verbose logging
  - [ ] Add DNS_VERBOSE environment variable support
  - [ ] Reduce function to <80 lines by extracting logging

- [ ] **Create Common Functions File**
  - [ ] Create new `common-functions` file with standard fallback functions
  - [ ] Move dokku_log_info1, dokku_log_info2, dokku_log_warn, dokku_log_fail definitions
  - [ ] Update all files to source common-functions instead of duplicating
  - [ ] Remove duplicate function definitions from 10+ files (commands, subcommands, hooks)

- [ ] **Simplify Complex Conditionals**
  - [ ] Refactor functions:363-397 to use early returns
  - [ ] Extract validation logic to separate functions
  - [ ] Create `handle_no_provider_validation` helper
  - [ ] Create `validate_domains_with_provider` helper
  - [ ] Reduce nesting depth in complex conditionals

- [ ] **Standardize Quoting**
  - [ ] Audit all variable references for missing quotes
  - [ ] Ensure all `$var` become `"$var"`
  - [ ] Ensure all `${array[@]}` become `"${array[@]}"`
  - [ ] Add linting rule to enforce proper quoting



- [ ] **Improve Documentation**
  - [ ] Add detailed comments to providers/aws/provider.sh:8-28
  - [ ] Document complex regex patterns and jq operations
  - [ ] Add function-level documentation for internal helpers
  - [ ] Document expected inputs, outputs, and side effects

- [ ] **Standardize Function Naming**
  - [ ] Create naming convention guide
  - [ ] Public API: `dns_*`
  - [ ] Internal helpers: `_dns_*` (underscore prefix)
  - [ ] Predicates: `is_*` or `has_*`
  - [ ] Getters: `get_*`, Setters: `set_*`
  - [ ] Refactor inconsistent function names across codebase

- [ ] **Add ShellCheck Directives**
  - [ ] Audit all shellcheck warnings
  - [ ] Add explicit `# shellcheck disable=SCXXXX` where needed
  - [ ] Add explanatory comments for each disable directive
  - [ ] Document why each check is disabled


## Future Enhancements

### Code Quality Improvements
- [ ] **Add Prettier for Markdown Formatting**
  - [ ] Install and configure Prettier for consistent markdown formatting
  - [ ] Add Prettier to pre-commit hooks alongside shellcheck
  - [ ] Format all existing documentation files with Prettier
  - [ ] Update developer workflow to include markdown formatting
  - [ ] Consider adding .prettierrc configuration for project-specific rules
