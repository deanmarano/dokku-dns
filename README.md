# dokku-dns

Automated DNS management for [Dokku](https://dokku.com) apps with multi-provider support (AWS Route53, Cloudflare, DigitalOcean).

## Prerequisites

- [Dokku](https://dokku.com) 0.19+
- DNS provider credentials (AWS Route53, Cloudflare, or DigitalOcean)

## Installation

```bash
dokku plugin:install https://github.com/deanmarano/dokku-dns.git dns
```

## Quick Start

```bash
# Configure your DNS provider
dokku config:set --global AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret
dokku dns:providers:verify aws

# Enable zones you want to manage
dokku dns:zones:enable example.com

# Enable automatic triggers (recommended)
dokku dns:triggers:enable

# DNS is now fully automatic — records are created when you add domains
dokku domains:add myapp example.com
```

## Commands

| Command | Description |
|---|---|
| `dns:apps` | List DNS-managed applications |
| `dns:apps:enable <app>` | Enable DNS management for an application |
| `dns:apps:disable <app>` | Disable DNS management for an application |
| `dns:apps:report <app>` | Display DNS status for an application |
| `dns:apps:sync <app>` | Synchronize DNS records for an application |
| `dns:cron [--enable\|--disable\|--schedule "..."]` | Manage automated DNS sync cron job |
| `dns:providers:verify [provider]` | Verify DNS provider setup and connectivity |
| `dns:records:create <record-value>` | Create a DNS record |
| `dns:records:delete <record-type>` | Delete a DNS record |
| `dns:records:get <record-type>` | Get the value of a DNS record |
| `dns:report [app]` | Display DNS status and domain info for app(s) |
| `dns:sync-all` | Synchronize DNS records for all managed apps |
| `dns:sync:deletions` | Remove DNS records from the pending deletions queue |
| `dns:triggers` | Show automatic management status |
| `dns:triggers:enable` | Enable automatic DNS management |
| `dns:triggers:disable` | Disable automatic DNS management |
| `dns:ttl [value]` | Get or set global DNS record TTL in seconds |
| `dns:version` | Show plugin version |
| `dns:zones [zone]` | List DNS zones and their status |
| `dns:zones:enable <zone>` | Enable a DNS zone for automatic management |
| `dns:zones:disable <zone>` | Disable a DNS zone |
| `dns:zones:sync <zone>` | Synchronize DNS records for apps in a zone |
| `dns:zones:ttl <zone> [value]` | Get or set TTL for a DNS zone |

## Provider Configuration

### AWS Route53

```bash
dokku config:set --global AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret
dokku dns:providers:verify aws
```

### Cloudflare

```bash
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token
dokku dns:providers:verify cloudflare
```

### DigitalOcean

```bash
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token
dokku dns:providers:verify digitalocean
```

## Automatic DNS Management

When triggers are enabled (`dokku dns:triggers:enable`), the plugin hooks into Dokku's app lifecycle:

- **Domain added** (`dokku domains:add`): Automatically creates an A record pointing to your server
- **Domain removed** (`dokku domains:remove`): Queues the DNS record for cleanup
- **App destroyed** (`dokku apps:destroy`): Queues all domains for cleanup

Queued deletions are applied when you run `dokku dns:sync:deletions`. This prevents accidental DNS disruption.

### Manual Mode

If you prefer manual control, disable triggers and manage DNS explicitly:

```bash
dokku dns:triggers:disable
dokku dns:apps:enable myapp
dokku dns:apps:sync myapp
```

## License

MIT
