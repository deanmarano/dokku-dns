# dokku dns [![Build Status](https://img.shields.io/github/actions/workflow/status/deanmarano/dokku-dns/ci.yml?branch=main&style=flat-square "Build Status")](https://github.com/deanmarano/dokku-dns/actions/workflows/ci.yml?query=branch%3Amain) [![IRC Network](https://img.shields.io/badge/irc-libera-blue.svg?style=flat-square "IRC Libera")](https://webchat.libera.chat/?channels=dokku)

**Automated DNS management for Dokku apps with multi-provider support**

Seamlessly manage DNS records for your Dokku applications across multiple cloud providers including AWS Route53, Cloudflare, and DigitalOcean. Automatically create, update, and synchronize DNS records as you deploy and manage your apps.

## ✨ Key Features

- 🚀 **Multi-Provider Support**: AWS Route53, Cloudflare, DigitalOcean, and extensible architecture for more providers
- 🔄 **Automatic Sync**: DNS records update automatically when you add domains or deploy apps
- 🎯 **Zone-Based Routing**: Intelligent routing of domains to appropriate DNS providers
- ⚡ **Batch Operations**: Efficient bulk DNS updates across all your apps
- 🕒 **TTL Management**: Flexible TTL configuration at global, zone, and domain levels
- 🛡️ **Production Ready**: Comprehensive error handling, retry logic, and extensive testing
- 📊 **Rich Reporting**: Clear status reports with visual indicators and troubleshooting info

## 🚀 Quick Start (5 minutes)

### 1. Install the Plugin

```shell
# Install from GitHub
sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git --name dns
```

### 2. Configure Your DNS Provider

**Option A: AWS Route53**
```shell
# Configure AWS credentials (choose one method)
dokku config:set --global AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret
# OR use AWS CLI: aws configure
# OR use IAM roles (recommended for EC2/ECS)

# Verify provider setup and discover zones
dokku dns:providers:verify aws
```

**Option B: Cloudflare**
```shell
# Set up Cloudflare API token
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token

# Verify provider setup and discover zones
dokku dns:providers:verify cloudflare
```

**Option C: DigitalOcean**
```shell
# Set up DigitalOcean API token
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token

# Verify provider setup and discover zones
dokku dns:providers:verify digitalocean
```

### 3. Enable DNS Zones

```shell
# List available zones discovered from your provider
dokku dns:zones

# Enable zones you want to manage (e.g., example.com)
dokku dns:zones:enable example.com

# Enable automatic triggers for seamless management
dokku dns:triggers:enable
```

### 4. Add Your App Domains

```shell
# Add domains to your app (if not already done)
dokku domains:add myapp example.com www.example.com

# Enable DNS management for the app
dokku dns:apps:enable myapp

# Sync DNS records (creates A records pointing to your server)
dokku dns:apps:sync myapp
```

### 5. Verify Everything Works

```shell
# Check DNS status for your app
dokku dns:report myapp

# View zone status
dokku dns:zones
```

🎉 **That's it!** Your DNS zones and app records are now managed automatically. When you add new domains to apps in managed zones, DNS records will be created and updated automatically.

## Requirements

- dokku 0.19.x+
- docker 1.8.x
- DNS provider credentials (AWS Route53 or Cloudflare)

## Installation

```shell
# on 0.19.x+
sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git --name dns
```

## Commands

```
dns:apps                                           # list DNS-managed applications
dns:apps:disable <app>                             # disable DNS management for an application
dns:apps:enable <app>                              # enable DNS management for an application
dns:apps:report <app>                              # display DNS status for a specific application
dns:apps:sync <app>                                # synchronize DNS records for an application
dns:cron [--enable|--disable|--schedule "CRON_SCHEDULE"] # manage automated DNS synchronization cron job
dns:providers:verify <provider-arg>                # verify DNS provider setup and connectivity
dns:report <app>                                   # display DNS status and domain information for app(s)
dns:sync-all                                       # synchronize DNS records for all DNS-managed apps
dns:sync:deletions <zone>                          # remove DNS records that no longer correspond to active Dokku apps
dns:triggers                                       # show DNS automatic management status
dns:triggers:disable                               # disable automatic DNS management for app lifecycle events
dns:triggers:enable                                # enable automatic DNS management for app lifecycle events
dns:ttl <ttl-value>                                # get or set the global DNS record TTL (time-to-live) in seconds
dns:version                                        # show DNS plugin version and dependency versions
dns:zones [<zone>]                                 # list DNS zones and their auto-discovery status
dns:zones:disable <zone>                           # disable DNS zone and remove managed domains
dns:zones:enable <zone>                            # enable DNS zone for automatic app domain management
dns:zones:ttl <zone>                               # get or set TTL (time-to-live) for a DNS zone in seconds
```

## Usage

Help for any commands can be displayed by specifying the command as an argument to dns:help. Plugin help output in conjunction with any files in the `docs/` folder is used to generate the plugin documentation. Please consult the `dns:help` command for any undocumented commands.

### Basic Usage

### enable DNS management for an application

```shell
# usage
dokku dns:apps:enable <app>
```

flags:

- `--ttl`: set custom TTL (time-to-live) in seconds for DNS records (60-86400)

Enable `DNS` management for an application:

```shell
dokku dns:apps:enable nextcloud
dokku dns:apps:enable nextcloud example.com api.example.com
dokku dns:apps:enable nextcloud --ttl 3600
dokku dns:apps:enable nextcloud example.com --ttl 1800
```

By default, adds all domains configured for the app optionally specify specific domains to add to `DNS` management optionally specify --ttl parameter to set custom `TTL` for these domains only domains with hosted zones in the `DNS` provider will be added this registers domains with the `DNS` provider but doesn`t update records yet use `dokku dns:apps:sync` to update `DNS` records:

### verify DNS provider setup and connectivity

```shell
# usage
dokku dns:providers:verify <provider-arg>
```

Verify `DNS` provider setup and connectivity, discover existing `DNS` records:

```shell
dokku dns:providers:verify [provider]
```

Verify specific provider or all available providers if none specified checks credentials, tests `API` access, shows available zones/domains for each provider:

### display DNS status and domain information for app(s)

```shell
# usage
dokku dns:report <app>
```

Display `DNS` status and domain information for app(s):

```shell
dokku dns:report [app]
```

Shows server `IP,` domains, `DNS` status with emojis, and hosted zones without app: shows all apps and their domains with app: shows detailed report for specific app `DNS` status: `CORRECT` correct, `WARNING` wrong `IP,` `ERROR` no record:

### synchronize DNS records for an application

```shell
# usage
dokku dns:apps:sync <app>
```

Synchronize `DNS` records for an application using the configured provider:

```shell
dokku dns:apps:sync nextcloud
```

This will discover all domains from the app and update `DNS` records to point to the current server's `IP` address using the configured provider:

### synchronize DNS records for all DNS-managed apps

```shell
# usage
dokku dns:sync-all
```

Synchronize `DNS` records for all apps with `DNS` management enabled:

```shell
dokku dns:sync-all
```

This will iterate through all apps that have `DNS` management enabled and sync their `DNS` records using the configured provider. `AWS` Route53 uses efficient batch `API` calls grouped by hosted zone. Other providers sync each app individually for compatibility.

