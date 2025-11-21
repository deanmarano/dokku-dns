# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Dokku plugin for DNS with multiple cloud providers. The plugin allows per-app domain management and DNS record management across different backends (AWS Route53, Cloudflare, etc.). It follows standard Dokku plugin architecture patterns.

The plugin is built as a shell-based Dokku service plugin that manages DNS configurations and manages domain records with cloud DNS providers on a per-application basis.

## Development Commands

### Testing
- `make lint` - Run shellcheck linting only
- `scripts/test-docker.sh` - Run comprehensive Docker-based tests (recommended)
- `scripts/test-server.sh` - Run tests against remote Dokku server (requires SSH setup)
- `make test` - Run lint + integration tests (requires local Dokku installation)
- `make unit-tests` - Run integration tests only (requires local Dokku installation)

### Development Setup
- `bash tests/setup.sh` - Setup test environment with Dokku
- `make ci-dependencies` - Install shellcheck, bats, and other tools

### Code Generation
- `make generate` - Generate README.md from help documentation
- `bin/generate` - Generate documentation from subcommand help

## Architecture

### Core Components

**Configuration Files:**
- `config` - Plugin configuration with environment variables and constants
- `log-functions` - Fallback logging functions (dokku_log_info1, etc.)
- `functions` - Main service logic (create, start, stop, link, unlink operations)

**Service Structure:**
- `subcommands/` - Individual command implementations (create, link, unlink, etc.)
- `commands` - Main command router and help system
- `plugin.toml` - Plugin metadata and configuration

**Key Variables (from config file):**
- `PLUGIN_COMMAND_PREFIX` - Command namespace (currently "dns")
- `PLUGIN_SERVICE` - Human readable service name
- `PLUGIN_DATA_ROOT` - Service data storage location
- `PLUGIN_DEFAULT_ALIAS` - Default environment variable alias

### DNS Specific Architecture

The DNS management should work as follows:

1. **Service Creation**: Create a DNS configuration for an app
2. **Backend Configuration**: Configure cloud provider credentials (AWS, Cloudflare)
3. **Domain Linking**: Link domains to applications for DNS management
4. **Sync Operations**: Manage DNS records when app domains change
5. **Multi-Backend Support**: Support multiple DNS providers simultaneously

### Expected Command Structure

Based on the current implementation, the DNS plugin supports:

```bash
dokku dns:configure [provider]                     # Configure DNS provider globally (defaults to aws)
dokku dns:verify                                   # Verify DNS provider setup and connectivity
dokku dns:add <app>                                # Add app domains to DNS management
dokku dns:sync <app>                               # Synchronize DNS records for app
dokku dns:report [app]                             # Show DNS status for app(s)
dokku dns:help                                     # Show all available commands
```

## Development Patterns

### Plugin Structure Conventions
- Each subcommand is a separate executable file in `subcommands/`
- Use `service_parse_args` for consistent flag parsing
- Follow the `service-*-cmd` function naming pattern
- Include help text in subcommand files using `#E` and `#F` comments

### Configuration Management
- Store service-specific config in `$PLUGIN_DATA_ROOT/$SERVICE/`
- Use property functions for key-value storage
- Maintain `LINKS` file for app associations

### Error Handling
- Use `dokku_log_fail` for fatal errors
- Use `verify_service_name` and `verify_app_name` for validation
- Check service existence before operations

### Testing
- Write integration tests for each subcommand in `tests/`
- Use `test_helper.bash` for common test utilities
- Follow existing test patterns for service lifecycle testing

## Key Files to Modify for DNS

1. **config** - Update plugin variables (PLUGIN_COMMAND_PREFIX, PLUGIN_SERVICE, etc.)
2. **plugin.toml** - Update plugin description and metadata
3. **functions** - DNS-specific logic for domain management
4. **subcommands/** - Adapt each subcommand for DNS functionality
5. **log-functions** - Fallback logging functions for compatibility

## DNS Backend Integration

### AWS Route53 Backend
- Use aws-cli for Route53 operations
- Store AWS credentials securely per service
- Support hosted zones and record management

### Cloudflare Backend  
- Use Cloudflare API for DNS operations
- Store API tokens securely per service
- Support zone and record management

### Multi-Backend Architecture
- Abstract DNS operations behind a common interface
- Allow services to use different backends
- Support backend-specific configuration and credentials
- never skip precommit tests