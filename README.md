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
dns:add <app>             # add app domains to dns provider for management
dns:configure <provider>  # configure or change the global dns provider
dns:cron                  # show automated DNS synchronization cron status and logs
dns:cron-disable          # disable automated DNS synchronization cron job
dns:cron-enable           # enable automated DNS synchronization via cron
dns:remove <app>          # remove app from dns management
dns:report <app>          # display DNS status and domain information for app(s)
dns:sync <app>            # synchronize DNS records for app
dns:sync-all              # synchronize DNS records for all DNS-managed apps
dns:verify                # verify DNS provider setup and connectivity
dns:version <aws-version> # show DNS plugin version and dependency versions
```

## Usage

Help for any commands can be displayed by specifying the command as an argument to dns:help. Plugin help output in conjunction with any files in the `docs/` folder is used to generate the plugin documentation. Please consult the `dns:help` command for any undocumented commands.

### Basic Usage

### add app domains to dns provider for management

```shell
# usage
dokku dns:add <app>
```

Add app domains to `DNS` provider for management:

```shell
dokku dns:add nextcloud
dokku dns:add nextcloud example.com api.example.com
```

By default, adds all domains configured for the app optionally specify specific domains to add to `DNS` management only domains with hosted zones in the `DNS` provider will be added this registers domains with the `DNS` provider but doesn`t update records yet use `dokku dns:sync` to update `DNS` records:

### configure or change the global dns provider

```shell
# usage
dokku dns:configure <provider>
```

Configure the global `DNS` provider:

```shell
dokku dns:configure [aws|cloudflare]
```

This sets up or changes the `DNS` provider for all `DNS` management. If no provider is specified, defaults to `$DNS_DEFAULT_PROVIDER` if provider is already configured, this will change to the new provider after configuration, use other commands to: - configure credentials: dokku dns:verify - sync an app: dokku dns:sync myapp:

### verify DNS provider setup and connectivity

```shell
# usage
dokku dns:verify
```

Verify `DNS` provider setup and connectivity, discover existing `DNS` records:

```shell
dokku dns:verify
```

For `AWS`:` checks if `AWS` `CLI` is configured, tests Route53 access, shows existing `DNS` records for Dokku domains for Cloudflare: prompts for `CLOUDFLARE_API_TOKEN` if not set, then validates access:

## AWS Setup

For AWS Route53, you need to configure the AWS CLI on your Dokku server. The DNS plugin will use your existing AWS CLI configuration instead of storing credentials.

**Prerequisites:**
1. Install AWS CLI on your Dokku server
2. Configure AWS credentials with proper Route53 permissions

### Install AWS CLI

```shell
# Ubuntu/Debian
sudo apt update && sudo apt install awscli

# Amazon Linux/CentOS
sudo yum install awscli

# Or install latest version via pip
pip install awscli
```

### Configure AWS Credentials

Choose one of these methods:

#### Option 1: Interactive Configuration (Recommended)
```shell
aws configure
```
This will prompt you for:
- AWS Access Key ID
- AWS Secret Access Key  
- Default region (e.g., us-east-1)
- Output format (json is recommended)

#### Option 2: Environment Variables
```shell
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"
```

#### Option 3: IAM Roles (EC2 only)
If your Dokku server runs on EC2, you can attach an IAM role with Route53 permissions instead of using access keys.

### Required AWS Permissions

Your AWS credentials need these Route53 permissions:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:ListResourceRecordSets",
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": "*"
        }
    ]
}
```

You can either:
- Attach the AWS managed policy **AmazonRoute53FullAccess**
- Or create a custom policy with the permissions above

### Verify Setup

After configuring AWS CLI, run:

```shell
dokku dns:verify
```

This will:
- Check if AWS CLI is installed and configured
- Verify your credentials work
- Test Route53 permissions
- List your hosted zones

## Cloudflare Setup

For Cloudflare, the plugin will prompt you for an API token during `dokku dns:verify`.

### Create Cloudflare API Token

1. Go to https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Use the **Custom token** template
4. Configure:
   - **Permissions**: Zone - Zone:Read, Zone - DNS:Edit
   - **Zone Resources**: Include - All zones (or specific zones)
5. Click **Continue to summary** and **Create Token**
6. Copy the token (you won't see it again)

### Configure Token

Run the verify command and enter your token when prompted:

```shell
dokku dns:verify
```

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

### synchronize DNS records for app

```shell
# usage
dokku dns:sync <app>
```

Synchronize `DNS` records for an app using the configured provider:

```shell
dokku dns:sync nextcloud
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
