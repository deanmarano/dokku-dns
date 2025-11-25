# dokku dns [![Build Status](https://img.shields.io/github/actions/workflow/status/deanmarano/dokku-dns/ci.yml?branch=main&style=flat-square "Build Status")](https://github.com/deanmarano/dokku-dns/actions/workflows/ci.yml?query=branch%3Amain) [![IRC Network](https://img.shields.io/badge/irc-libera-blue.svg?style=flat-square "IRC Libera")](https://webchat.libera.chat/?channels=dokku)

**Automated DNS management for Dokku apps with multi-provider support**

Seamlessly manage DNS records for your Dokku applications across multiple cloud providers including AWS Route53, Cloudflare, and DigitalOcean. Automatically create, update, and synchronize DNS records as you deploy and manage your apps.

## ✨ Key Features

- 🤖 **Fully Automatic**: Enable triggers once, never think about DNS again - records are created, updated, and cleaned up automatically
- 🚀 **Multi-Provider Support**: AWS Route53, Cloudflare, DigitalOcean, and extensible architecture for more providers
- 🔄 **Lifecycle Integration**: Hooks into Dokku's app lifecycle (create, domains add/remove, destroy) for seamless DNS management
- 🎯 **Zone-Based Routing**: Intelligent routing of domains to appropriate DNS providers
- ⚡ **Batch Operations**: Efficient bulk DNS updates across all your apps
- 🕒 **TTL Management**: Flexible TTL configuration at global, zone, and domain levels (default: 300 seconds)

## 🚀 Quick Start

### 1. Install the Plugin

```shell
sudo dokku plugin:install https://github.com/deanmarano/dokku-dns.git --name dns
```

### 2. Configure Your DNS Provider

**Option A: AWS Route53**
```shell
dokku config:set --global AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret
dokku dns:providers:verify aws
```

**Option B: Cloudflare**
```shell
dokku config:set --global CLOUDFLARE_API_TOKEN=your_api_token
dokku dns:providers:verify cloudflare
```

**Option C: DigitalOcean**
```shell
dokku config:set --global DIGITALOCEAN_ACCESS_TOKEN=your_api_token
dokku dns:providers:verify digitalocean
```

### 3. Enable Automatic DNS Management

```shell
# Enable zones you want to manage
dokku dns:zones:enable example.com

# Enable automatic triggers (RECOMMENDED)
dokku dns:triggers:enable
```

🎉 **That's it!** DNS is now fully automatic. The plugin will:
- ✅ **Automatically add domains** to DNS when you run `dokku domains:add`
- ✅ **Automatically create DNS records** pointing to your server
- ✅ **Automatically queue cleanup** when you remove domains or destroy apps

### Example: Deploy an App with Automatic DNS

```shell
# Create and deploy your app
dokku apps:create myapp
git push dokku main

# Add domains - DNS records are created automatically!
dokku domains:add myapp example.com
dokku domains:add myapp www.example.com

# Check DNS status
dokku dns:report myapp
```

## 🤖 How Automatic DNS Management Works

When you enable triggers with `dokku dns:triggers:enable` and enable zones with `dokku dns:zones:enable`, the plugin automatically manages DNS for your apps without any manual intervention.

### When You Add a Domain

```shell
dokku domains:add myapp example.com
```

**What happens automatically:**
1. ✅ Plugin detects the domain was added (via `post-domains-update` trigger)
2. ✅ Checks if `example.com` is in an enabled zone
3. ✅ Adds the domain to DNS tracking for `myapp`
4. ✅ **Automatically syncs DNS** - creates an A record pointing to your server
5. ✅ Confirms DNS record created successfully

**Result:** The domain is immediately accessible via DNS, no manual sync needed!

### When You Remove a Domain

```shell
dokku domains:remove myapp example.com
```

**What happens automatically:**
1. ✅ Plugin detects the domain was removed (via `post-domains-update` trigger)
2. ✅ Removes the domain from DNS tracking
3. ✅ **Queues the DNS record for cleanup**
4. ⏳ DNS record stays in place temporarily (safety feature)
5. 🧹 Run `dokku dns:sync:deletions` when ready to remove DNS records

**Why queue deletions?** This prevents accidental DNS disruption. You control when orphaned records are actually deleted.

### When You Destroy an App

```shell
dokku apps:destroy myapp
```

**What happens automatically:**
1. ✅ Plugin detects the app was destroyed (via `post-delete` trigger)
2. ✅ Removes all DNS tracking for the app
3. ✅ **Queues all domains for cleanup**
4. ✅ Removes app from DNS management
5. 🧹 Run `dokku dns:sync:deletions` to clean up DNS records

### Manual Mode (Without Triggers)

If you prefer manual control, you can disable triggers and manage DNS explicitly:

```shell
# Disable automatic management
dokku dns:triggers:disable

# Manual workflow
dokku domains:add myapp example.com    # Add domain
dokku dns:apps:enable myapp            # Enable DNS management
dokku dns:apps:sync myapp              # Manually sync DNS records
```

## Requirements

- dokku 0.19.x+
- docker 1.8.x
- DNS provider credentials (AWS Route53, Cloudflare, or DigitalOcean)

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
dns:sync:deletions                                 # remove DNS records from the pending deletions queue
dns:triggers                                       # show DNS automatic management status
dns:triggers:disable                               # disable automatic DNS management for app lifecycle events
dns:triggers:enable                                # enable automatic DNS management for app lifecycle events
dns:ttl <ttl-value>                                # get or set the global DNS record TTL (time-to-live) in seconds
dns:version                                        # show DNS plugin version and dependency versions
dns:zones [<zone>]                                 # list DNS zones and their auto-discovery status
dns:zones:disable <zone>                           # disable DNS zone and remove managed domains
dns:zones:enable <zone>                            # enable DNS zone for automatic app domain management
dns:zones:sync <zone>                              # synchronize DNS records for apps within a zone
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
- `-v|--verbose`: show detailed domain checking progress

Enable `DNS` management for an application:

```shell
dokku dns:apps:enable nextcloud
dokku dns:apps:enable nextcloud example.com api.example.com
dokku dns:apps:enable nextcloud --ttl 3600
dokku dns:apps:enable nextcloud example.com --ttl 1800
dokku dns:apps:enable nextcloud --verbose
```

By default, adds all domains configured for the app optionally specify specific domains to add to `DNS` management optionally specify --ttl parameter to set custom `TTL` for these domains only domains with hosted zones in the `DNS` provider will be added this registers domains with the `DNS` provider but doesn`t update records yet use `dokku dns:apps:sync` to update `DNS` records:

### verify DNS provider setup and connectivity

```shell
# usage
dokku dns:providers:verify <provider-arg>
```

flags:

- `-v|--verbose`: show detailed output (default shows summary only)

Verify `DNS` provider setup and connectivity, discover existing `DNS` records:

```shell
dokku dns:providers:verify [--verbose] [provider]
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

