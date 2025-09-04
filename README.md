# dokku dns [![Build Status](https://img.shields.io/github/actions/workflow/status/deanmarano/dokku-dns/ci.yml?branch=main&style=flat-square "Build Status")](https://github.com/deanmarano/dokku-dns/actions/workflows/ci.yml?query=branch%3Amain) [![IRC Network](https://img.shields.io/badge/irc-libera-blue.svg?style=flat-square "IRC Libera")](https://webchat.libera.chat/?channels=dokku)

A dns plugin for dokku. Manages DNS records with cloud providers like AWS Route53 and Cloudflare.

## Requirements

- dokku 0.19.x+
- docker 1.8.x

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
dns:sync:deletions.bak <zone>                      # remove DNS records that no longer correspond to active Dokku apps
dns:triggers                                       # show DNS automatic management status
dns:triggers:disable                               # disable automatic DNS management for app lifecycle events
dns:triggers:enable                                # enable automatic DNS management for app lifecycle events
dns:version                                        # show DNS plugin version and dependency versions
dns:zones [<zone>]                                 # list DNS zones and their auto-discovery status
dns:zones:disable <zone>                           # disable DNS zone and remove managed domains
dns:zones:enable <zone>                            # enable DNS zone for automatic app domain management
```

## Usage

Help for any commands can be displayed by specifying the command as an argument to dns:help. Plugin help output in conjunction with any files in the `docs/` folder is used to generate the plugin documentation. Please consult the `dns:help` command for any undocumented commands.

### Basic Usage

### enable DNS management for an application

```shell
# usage
dokku dns:apps:enable <app>
```

Enable `DNS` management for an application:

```shell
dokku dns:apps:enable nextcloud
dokku dns:apps:enable nextcloud example.com api.example.com
```

By default, adds all domains configured for the app optionally specify specific domains to add to `DNS` management only domains with hosted zones in the `DNS` provider will be added this registers domains with the `DNS` provider but doesn`t update records yet use `dokku dns:apps:sync` to update `DNS` records:

### verify DNS provider setup and connectivity

```shell
# usage
dokku dns:providers:verify <provider-arg>
```

Verify `DNS` provider setup and connectivity, discover existing `DNS` records:

```shell
dokku dns:providers:verify [provider]
```

Verify configured provider or specific provider if specified for `AWS`:` checks if `AWS` `CLI` is configured, tests Route53 access, shows existing `DNS` records for Dokku domains:

### display DNS status and domain information for app(s)

```shell
# usage
dokku dns:report <app>
```

Display `DNS` status and domain information for app(s):

```shell
dokku dns:report [app]
```

Shows server `IP,` domains, `DNS` status with emojis, and hosted zones without app: shows all apps and their domains with app: shows detailed report for specific app `DNS` status: ✅ correct, ⚠️ wrong `IP,` ❌ no record:

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

### Disabling `docker image pull` calls

If you wish to disable the `docker image pull` calls that the plugin triggers, you may set the `DNS_DISABLE_PULL` environment variable to `true`. Once disabled, you will need to pull the service image you wish to deploy as shown in the `stderr` output.

Please ensure the proper images are in place when `docker image pull` is disabled.
