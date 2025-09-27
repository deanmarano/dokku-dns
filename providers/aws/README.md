# AWS Route53 DNS Provider

This provider integrates with Amazon Web Services (AWS) Route53 to manage DNS records for your Dokku applications.

## Features

- Full support for AWS Route53 hosted zones and DNS records
- Automatic zone detection (finds parent zones for subdomains)
- Record creation, updates, and deletion using AWS Route53 API
- Comprehensive error handling and AWS CLI integration
- Batch operations support for efficient Route53 API usage
- Works alongside other DNS providers in multi-provider setups

## Setup

### 1. Install Dependencies

The AWS provider requires both AWS CLI v2 and jq:

```bash
# On macOS (Homebrew)
brew install awscli jq

# On Ubuntu/Debian
sudo apt-get update
sudo apt-get install awscli jq

# On Amazon Linux
sudo yum install awscli jq

# On CentOS/RHEL/Rocky Linux
sudo dnf install awscli jq
```

### 2. Configure AWS Credentials

You can configure AWS credentials in several ways:

#### Option A: Environment Variables (Recommended for Dokku)
```bash
# Set via Dokku config
dokku config:set --global AWS_ACCESS_KEY_ID="your_access_key_id"
dokku config:set --global AWS_SECRET_ACCESS_KEY="your_secret_access_key"
dokku config:set --global AWS_DEFAULT_REGION="us-east-1"
```

#### Option B: AWS CLI Configuration
```bash
aws configure
```

#### Option C: IAM Role (for EC2 instances)
If running on EC2, attach an IAM role with Route53 permissions to your instance.

### 3. Required IAM Permissions

Your AWS credentials must have the following Route53 permissions:

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
        },
        {
            "Effect": "Allow",
            "Action": [
                "sts:GetCallerIdentity"
            ],
            "Resource": "*"
        }
    ]
}
```

### 4. Create Hosted Zones

Ensure you have Route53 hosted zones for your domains:

1. Go to [AWS Route53 Console](https://console.aws.amazon.com/route53/)
2. Click "Hosted zones" → "Create hosted zone"
3. Enter your domain name (e.g., `example.com`)
4. Choose "Public hosted zone"
5. Update your domain's nameservers to point to the AWS nameservers provided

## Usage

### Verify Provider Setup

```bash
dokku dns:providers:verify aws
```

This will check:
- AWS CLI installation
- Credential configuration
- Route53 API access
- Available hosted zones

### Add Domains to DNS Management

```bash
# Enable DNS management for an app
dokku dns:apps:enable myapp

# Sync DNS records
dokku dns:apps:sync myapp
```

### Check DNS Status

```bash
# App-specific DNS report
dokku dns:apps:report myapp

# Global DNS report
dokku dns:report
```

## Troubleshooting

### Common Issues

**"AWS CLI not installed"**
- Install AWS CLI using the instructions above
- Verify installation: `aws --version`

**"AWS credentials not configured or invalid"**
- Check credentials: `aws sts get-caller-identity`
- Reconfigure: `aws configure` or set environment variables

**"Hosted zone not found for domain"**
- Create a hosted zone in Route53 for your domain
- Verify the domain matches exactly (including subdomains)
- Update your domain's nameservers to point to AWS

**"Access denied" errors**
- Verify your IAM permissions include Route53 access
- Check that your credentials have the required permissions listed above

### Testing AWS Integration

```bash
# Test AWS CLI access
aws sts get-caller-identity

# List your hosted zones
aws route53 list-hosted-zones

# Test provider validation
dokku dns:providers:verify aws
```

## Multi-Provider Support

AWS Route53 works seamlessly with other DNS providers. The plugin automatically detects which provider manages each zone:

```bash
# AWS manages example.com, Cloudflare manages other.com
dokku dns:apps:enable myapp  # Will use appropriate provider for each domain
```

## Advanced Configuration

### Custom TTL Settings

The provider uses a default TTL of 300 seconds. You can customize this in your provider configuration.

### Batch Operations

The AWS provider supports efficient batch operations for multiple DNS records, reducing API calls and improving performance.

### Region Configuration

Set your preferred AWS region:

```bash
dokku config:set --global AWS_DEFAULT_REGION="us-west-2"
```

## API Limits

AWS Route53 has the following limits:
- 100 resource record sets per hosted zone by default
- Rate limiting on API calls (handled automatically)
- 1000 hosted zones per account by default

For higher limits, contact AWS support.