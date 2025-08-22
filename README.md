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
dns:help [<command>]                               # show help for DNS commands or specific subcommand
dns:providers:configure [<provider>]               # configure or change the global DNS provider
dns:providers:verify [<provider>]                  # verify DNS provider setup and connectivity
dns:report [<app>]                                 # display DNS status and domain information for app(s)
dns:sync-all                                       # synchronize DNS records for all DNS-managed apps
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

# example  
dokku dns:apps:enable nextcloud
```

Enable DNS management for an application. This will add the app to DNS tracking and prepare it for DNS record synchronization.

### disable DNS management for an application

```shell
# usage
dokku dns:apps:disable <app>

# example
dokku dns:apps:disable nextcloud
```

Disable DNS management for an application and remove it from DNS tracking.

### configure or change the global DNS provider

```shell
# usage
dokku dns:providers:configure [<provider>]

# examples
dokku dns:providers:configure
dokku dns:providers:configure aws
```

Configure the global DNS provider. Defaults to AWS if no provider is specified.

### manage automated DNS synchronization cron job

```shell
# usage
dokku dns:cron [--enable|--disable|--schedule "CRON_SCHEDULE"]

# examples
dokku dns:cron
dokku dns:cron --enable
dokku dns:cron --disable
dokku dns:cron --schedule "0 6 * * *"
```

Manage automated DNS synchronization cron job that syncs all DNS-managed apps.

### show help for DNS commands or specific subcommand

```shell
# usage
dokku dns:help [<command>]

# examples
dokku dns:help
dokku dns:help apps:enable
```

Show help for DNS commands. Can show general help or help for a specific subcommand.

### display DNS status for a specific application

```shell
# usage
dokku dns:apps:report <app>

# example
dokku dns:apps:report nextcloud
```

Display DNS status and configuration for a specific application.

### synchronize DNS records for an application

```shell
# usage
dokku dns:apps:sync <app>

# example
dokku dns:apps:sync nextcloud
```

Synchronize DNS records for an application with the configured DNS provider.

### verify DNS provider setup and connectivity

```shell
# usage
dokku dns:providers:verify [<provider>]

# examples
dokku dns:providers:verify
dokku dns:providers:verify aws
```

Verify DNS provider setup and connectivity. Can verify the global provider or a specific provider.

### display DNS status and domain information for app(s)

```shell
# usage
dokku dns:report [<app>]

# examples
dokku dns:report
dokku dns:report nextcloud
```

Display DNS status and domain information. Without arguments, shows all DNS-managed apps. With an app name, shows detailed information for that app.

### synchronize DNS records for all DNS-managed apps

```shell
# usage
dokku dns:sync-all
```

Synchronize DNS records for all applications currently under DNS management.

### show DNS plugin version and dependency versions

```shell
# usage
dokku dns:version
```

Show the DNS plugin version and versions of dependencies like AWS CLI.

### list DNS zones and their auto-discovery status

```shell
# usage
dokku dns:zones [<zone>]

# examples
dokku dns:zones
dokku dns:zones example.com
```

List DNS zones and their auto-discovery status. Can show all zones or details for a specific zone.

### enable DNS zone for automatic app domain management

```shell
# usage
dokku dns:zones:enable <zone>

# example
dokku dns:zones:enable example.com
```

Enable DNS zone for automatic app domain management.

### disable DNS zone and remove managed domains

```shell
# usage
dokku dns:zones:disable <zone>

# example
dokku dns:zones:disable example.com
```

Disable DNS zone and remove managed domains.