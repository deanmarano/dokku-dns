# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Dokku DNS plugin for automated DNS management across multiple cloud providers (AWS Route53, Cloudflare, DigitalOcean). Automatically creates, updates, and synchronizes DNS records as apps are deployed and managed.

## Development Commands

### Testing
```bash
make lint                    # Run shellcheck + shfmt format check
make test                    # Run lint + BATS unit tests
make unit-tests              # Run BATS unit tests only
make docker-test             # Run integration tests in Docker (recommended)
scripts/test-docker.sh       # Docker tests with options (--build, --logs, --direct)
```

### Running a Single Test
```bash
bats tests/dns_help.bats              # Run specific test file
bats tests/dns_help.bats --filter "shows main help"  # Run single test by name
```

### Code Formatting
```bash
make format        # Auto-format shell files with shfmt
make format-check  # Check formatting without modifying
```

### Documentation Generation
```bash
make generate      # Generate README.md from subcommand help text
```

## Architecture

### Provider System (Multi-Provider)

The plugin uses a layered provider architecture in `providers/`:

```
providers/
├── loader.sh          # Provider discovery and loading
├── adapter.sh         # High-level plugin operations (dns_sync_app, apply_dns_record)
├── multi-provider.sh  # Zone-to-provider routing
├── aws/provider.sh    # AWS Route53 implementation
├── cloudflare/provider.sh
├── digitalocean/provider.sh
└── mock/provider.sh   # For testing
```

**Provider Interface** - Each provider must implement:
- `provider_validate_credentials` - Test API access
- `provider_list_zones` - List available DNS zones
- `provider_get_zone_id` - Get zone ID for a domain
- `provider_get_record` - Get current record value
- `provider_create_record` - Create/update DNS record
- `provider_delete_record` - Remove DNS record

**Zone Routing** - `multi-provider.sh` routes domains to the correct provider based on discovered zones stored in `$PLUGIN_DATA_ROOT/.multi-provider/zones/`.

### Data Storage

```
$PLUGIN_DATA_ROOT/                    # /var/lib/dokku/services/dns
├── LINKS                             # List of DNS-managed apps
├── ENABLED_ZONES                     # Zones enabled for auto-discovery
├── GLOBAL_TTL                        # Global TTL setting
├── MANAGED_RECORDS                   # Tracked records (domain:zone_id:timestamp)
├── PENDING_DELETIONS                 # Queue for safe deletion
├── .multi-provider/                  # Provider zone mappings
│   ├── providers/<provider>          # Zones per provider
│   └── zones/<zone>                  # Provider per zone
└── <app>/
    ├── DOMAINS                       # Domains managed for this app
    └── DOMAIN_TTLS                   # Per-domain TTL overrides
```

### Command Structure

All commands live in `subcommands/` as executable scripts:

```bash
# App management
dokku dns:apps                         # List DNS-managed apps
dokku dns:apps:enable <app>            # Enable DNS for app
dokku dns:apps:disable <app>           # Disable DNS for app
dokku dns:apps:sync <app>              # Sync DNS records for app
dokku dns:apps:report <app>            # Show app DNS status

# Zone management
dokku dns:zones                        # List zones and status
dokku dns:zones:enable <zone>          # Enable zone for auto-discovery
dokku dns:zones:disable <zone>         # Disable zone
dokku dns:zones:sync <zone>            # Sync all apps in zone

# Provider operations
dokku dns:providers:verify [provider]  # Verify provider credentials

# Global operations
dokku dns:sync-all                     # Sync all DNS-managed apps
dokku dns:sync:deletions               # Process pending deletion queue
dokku dns:triggers:enable              # Enable automatic DNS on domain changes
dokku dns:triggers:disable             # Disable automatic DNS
dokku dns:ttl [value]                  # Get/set global TTL
dokku dns:report [app]                 # Show DNS status

# Record management
dokku dns:records:create <domain> <type> <value>  # Create arbitrary record
dokku dns:records:get <domain> <type>             # Get record value
dokku dns:records:delete <domain> <type>          # Delete record
```

### Trigger Integration

Dokku lifecycle hooks in root directory:
- `post-domains-update` - Auto-sync when domains change (if triggers enabled)
- `post-delete` - Queue deletions when app destroyed

### Testing Patterns

Tests use BATS with mocks in `tests/`:
- `test_helper.bash` - Common setup, mocks for dokku/aws/crontab
- `tests/bin/` - Mock executables (aws, dokku)
- `mock_dokku_environment.bash` - Environment overrides for CI

```bash
# Test file structure
@test "(dns:command) test description" {
  run dokku dns:command args
  assert_success
  assert_output_contains "expected text"
}
```

Helper functions: `assert_success`, `assert_failure`, `assert_output_contains`, `assert_file_exists`, `setup_multi_provider_test_data`

## Key Conventions

- Never skip pre-commit hooks
- Use `dokku_log_fail` for fatal errors, `dokku_log_warn` for warnings
- Store app data in `$PLUGIN_DATA_ROOT/<app>/`
- TTL hierarchy: domain-specific → zone-specific → global (default 300s)
- Provider credentials via environment variables (AWS_ACCESS_KEY_ID, CLOUDFLARE_API_TOKEN, etc.)