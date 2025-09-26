# AWS Route53 Provider Setup

This guide covers setting up AWS Route53 as a DNS provider for the Dokku DNS plugin.

## Prerequisites

- AWS account with Route53 access
- Domain with hosted zone in Route53
- Dokku DNS plugin installed

## Setup

### 1. Configure Credentials

Choose one method:

**Environment Variables:**
```shell
dokku config:set --global AWS_ACCESS_KEY_ID=your_key
dokku config:set --global AWS_SECRET_ACCESS_KEY=your_secret
dokku config:set --global AWS_DEFAULT_REGION=us-east-1
```

**AWS CLI:**
```shell
aws configure
```

**IAM Role (EC2):**
Attach IAM role with Route53 permissions - auto-detected.

### 2. IAM Policy

Minimal required permissions:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "route53:ListHostedZones",
                "route53:GetHostedZone",
                "route53:ListResourceRecordSets",
                "route53:ChangeResourceRecordSets",
                "route53:GetChange"
            ],
            "Resource": "*"
        }
    ]
}
```

### 3. Verify Setup

```shell
# Test connectivity
dokku dns:providers:verify aws

# Enable zones
dokku dns:zones:enable example.com

# Enable app
dokku dns:apps:enable myapp
dokku dns:apps:sync myapp
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AWS_ACCESS_KEY_ID` | AWS access key | None |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | None |
| `AWS_DEFAULT_REGION` | AWS region | `us-east-1` |
| `AWS_PROFILE` | AWS CLI profile | `default` |

### App-Specific Configuration

```shell
# Use different profile for specific app
dokku config:set --no-restart myapp AWS_PROFILE=staging
```

## Troubleshooting

**Credentials Error:**
```shell
# Check AWS CLI configuration
aws sts get-caller-identity

# Verify IAM permissions
aws route53 list-hosted-zones
```

**Zone Not Found:**
```shell
# List available zones
aws route53 list-hosted-zones

# Check nameserver delegation
dig NS example.com
```

**Rate Limiting:**
AWS Route53 has a 5 requests/second limit. The plugin includes automatic retry with exponential backoff.

## Multi-Provider Usage

```shell
# AWS for corporate domains
export AWS_ACCESS_KEY_ID=corporate_key
dokku dns:zones:enable corporate.com

# Other providers for other domains
export CLOUDFLARE_API_TOKEN=personal_token
dokku dns:zones:enable personal.dev
```