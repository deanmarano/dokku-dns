# Changelog

All notable changes to the Dokku DNS plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-11-18

First tagged release. Everything below this entry was developed before
releases were tagged and ships in 0.4.0 too.

### Added
- **OVHcloud DNS provider**, supporting OAuth2 and legacy signed API credentials (#97, thanks @monperrus)
- **DNS record commands** for arbitrary record types (`dns:records:*`)
- Provider credentials are loaded from dokku global config
- `dns:version` reports the git commit and commit time
- Upgrade directions in the README

### Fixed
- Bare `help` no longer exits 10, which broke `dokku help --all` and the dokku
  package postinst (#99, thanks @AntonioIbarraOrtiz)
- `install` no longer changes file permissions inside the plugin checkout,
  which made `dokku plugin:update` fail
- Never delete a domain that is still a live vhost; tracked domains are
  reconciled against dokku vhosts on sync
- Global vhosts are synced by `dns:sync:all`
- Server IP is detected from the host rather than from its own DNS records
- Empty `update` trigger avoids exit 10 on `plugin:update`

## Pre-0.4.0 development

### Added
- **Multi-provider DNS support**: AWS Route53, Cloudflare, and DigitalOcean providers
- **Provider verification command**: `dokku dns:providers:verify` with auto-detection and troubleshooting
- **Automated DNS synchronization**: Cron-based automation with `dokku dns:cron` commands
- **Zone management**: Enable/disable zones with `dokku dns:zones` commands
- **Batch operations**: Sync all apps with `dokku dns:sync-all` and deletion cleanup
- **Comprehensive reporting**: Enhanced `dokku dns:report` with visual status indicators
- **Trigger system**: Automatic DNS management during app lifecycle events
- **TTL configuration**: Global and zone-specific TTL management
- **Dependency management**: Automatic jq installation and validation

### Changed
- **Improved command structure**: Organized commands with consistent naming (`dns:apps:*`, `dns:zones:*`)
- **Enhanced error messages**: Clear, actionable error messages with troubleshooting guidance
- **Streamlined output**: Removed verbose messages, focused on essential information
- **Better user experience**: Smart defaults and helpful guidance for common scenarios
- **Modernized JSON processing**: Standardized jq usage across all providers
- **Robust testing**: 183+ integration tests covering edge cases and multi-provider scenarios

### Fixed
- **Command routing**: Fixed issues with colon-syntax commands (`dns:providers:verify`)
- **Docker compatibility**: Enhanced test stability in containerized environments
- **Provider edge cases**: Improved error handling for API failures and network issues
- **Race conditions**: Better synchronization in multi-provider scenarios
- **Permission handling**: Improved crontab management across different user contexts

---

## Development Notes

For detailed development history and technical implementation details, see the complete 24-phase development journey documented in this changelog's commit history. Major phases included:

- **Phases 1-5**: Core foundation and basic AWS integration
- **Phases 6-10**: Multi-app support and batch operations
- **Phases 11-15**: Enhanced user experience and reporting
- **Phases 16-20**: Advanced features and output standardization
- **Phases 21-24**: Multi-provider support and production readiness
