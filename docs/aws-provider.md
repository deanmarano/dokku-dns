# AWS Route53 Provider Setup Guide

AWS Route53 is a highly available and scalable DNS web service that integrates seamlessly with the DNS plugin. This guide covers complete setup, configuration, and best practices.

## Prerequisites

- AWS account with Route53 access
- Domain(s) registered or delegated to Route53 hosted zones
- Dokku DNS plugin installed

## Quick Setup

### 1. Configure AWS Credentials

Choose one of the following methods:

**Option A: Environment Variables (Simplest)**
```shell
# Set AWS credentials globally in Dokku
dokku config:set --global AWS_ACCESS_KEY_ID=your_access_key_id
dokku config:set --global AWS_SECRET_ACCESS_KEY=your_secret_access_key
dokku config:set --global AWS_DEFAULT_REGION=us-east-1
```

**Option B: AWS CLI Configuration**
```shell
# Install AWS CLI if not already installed
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and default region
```

**Option C: IAM Roles (Recommended for EC2)**
```shell
# If running on EC2, attach an IAM role with Route53 permissions
# No additional configuration needed - credentials auto-detected
```

### 2. Create IAM Policy and User

**Minimal IAM Policy for DNS Plugin:**
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
                "route53:ChangeResourceRecordSets"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "route53:GetChange"
            ],
            "Resource": "arn:aws:route53:::change/*"
        }
    ]
}
```

**Create IAM User and Policy:**
```shell
# Create policy
aws iam create-policy --policy-name dokku-dns-policy --policy-document file://dns-policy.json

# Create user
aws iam create-user --user-name dokku-dns

# Attach policy to user
aws iam attach-user-policy --user-name dokku-dns --policy-arn arn:aws:iam::ACCOUNT-ID:policy/dokku-dns-policy

# Create access keys
aws iam create-access-key --user-name dokku-dns
```

### 3. Set Up Hosted Zones

**Create hosted zone for your domain:**
```shell
# Create hosted zone
aws route53 create-hosted-zone --name example.com --caller-reference $(date +%s)

# Update domain registrar's nameservers with Route53 nameservers
aws route53 get-hosted-zone --id /hostedzone/Z123456789 --query 'DelegationSet.NameServers'
```

### 4. Verify Setup

```shell
# Test DNS provider connectivity
dokku dns:providers:verify aws

# Check available zones
dokku dns:zones

# Enable zones for management
dokku dns:zones:enable example.com
```

## Advanced Configuration

### Multiple AWS Accounts

```shell
# Use AWS profiles for different accounts
aws configure --profile production
aws configure --profile staging

# Set profile for Dokku
dokku config:set --global AWS_PROFILE=production
```

### Cross-Account Zone Access

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sts:AssumeRole"
            ],
            "Resource": "arn:aws:iam::OTHER-ACCOUNT:role/DnsManagementRole"
        }
    ]
}
```

### VPC and Private Zones

```shell
# Create private hosted zone
aws route53 create-hosted-zone \
    --name internal.example.com \
    --vpc VPCRegion=us-east-1,VPCId=vpc-123456 \
    --caller-reference $(date +%s)
```

## Performance and Scaling

### API Rate Limits

- Route53 allows **5 requests per second** per AWS account
- DNS plugin includes automatic retry logic and exponential backoff
- For high-volume operations, consider:

```shell
# Use batch operations when possible
dokku dns:sync-all  # More efficient than individual syncs
```

### Cost Optimization

- **Hosted Zone**: $0.50 per zone per month
- **DNS Queries**: $0.40 per million queries for first 1B queries
- **Health Checks**: $0.50 per health check per month

```shell
# Monitor costs
aws route53 get-query-logging-config --id your-config-id

# Use longer TTLs to reduce query costs
dokku dns:zones:ttl example.com 3600
```

## Troubleshooting

### Common Issues

**1. Permission Denied**
```shell
# Check IAM permissions
aws sts get-caller-identity
aws iam get-user

# Verify policy attachment
aws iam list-attached-user-policies --user-name dokku-dns
```

**2. Zone Not Found**
```shell
# List all hosted zones
aws route53 list-hosted-zones

# Check zone delegation
dig NS example.com
```

**3. API Rate Limiting**
```shell
# Check CloudTrail for throttling events
aws logs filter-log-events --log-group-name CloudTrail/Route53API
```

**4. Invalid Credentials**
```shell
# Test credentials
aws route53 list-hosted-zones

# Regenerate access keys if needed
aws iam create-access-key --user-name dokku-dns
```

### Debug Mode

```shell
# Enable debug logging
dokku config:set --global AWS_DEBUG=1

# Check plugin logs
dokku dns:providers:verify aws 2>&1 | grep -i error
```

## Security Best Practices

### 1. Least Privilege Access

- Use minimal IAM policies with only required permissions
- Restrict access to specific hosted zones when possible:

```json
{
    "Resource": [
        "arn:aws:route53:::hostedzone/Z123456789",
        "arn:aws:route53:::change/*"
    ]
}
```

### 2. Credential Rotation

```shell
# Rotate access keys regularly (quarterly recommended)
aws iam create-access-key --user-name dokku-dns
# Update Dokku configuration
dokku config:set --global AWS_ACCESS_KEY_ID=new_key
# Delete old key after testing
aws iam delete-access-key --user-name dokku-dns --access-key-id old_key
```

### 3. MFA for Admin Access

```shell
# Enable MFA for IAM user (admin operations only)
aws iam create-virtual-mfa-device --virtual-mfa-device-name dokku-dns-mfa
```

### 4. CloudTrail Monitoring

```shell
# Enable CloudTrail for Route53 API calls
aws cloudtrail create-trail --name route53-audit --s3-bucket-name audit-logs
```

## Integration Examples

### Development/Staging Setup

```shell
# Use separate AWS account or zones for development
dokku config:set --no-restart myapp AWS_PROFILE=staging
dokku dns:apps:enable myapp staging.example.com --ttl 60
```

### Production Setup

```shell
# Use IAM roles with production account
dokku config:set --global AWS_DEFAULT_REGION=us-east-1
dokku dns:zones:enable example.com
dokku dns:zones:ttl example.com 3600  # Higher TTL for production
```

### Multi-Region Setup

```shell
# Configure different regions for different zones
dokku config:set --global AWS_DEFAULT_REGION=us-west-2
# Route53 is global, but this affects other AWS services
```

## Monitoring and Alerts

### CloudWatch Metrics

```shell
# Monitor Route53 query count
aws cloudwatch get-metric-statistics \
    --namespace AWS/Route53 \
    --metric-name QueryCount \
    --dimensions Name=HostedZoneId,Value=Z123456789 \
    --start-time 2023-01-01T00:00:00Z \
    --end-time 2023-01-02T00:00:00Z \
    --period 3600 \
    --statistics Sum
```

### DNS Health Checks

```shell
# Create health check for critical domains
aws route53 create-health-check \
    --caller-reference $(date +%s) \
    --health-check-config Type=HTTPS,ResourcePath=/health,FullyQualifiedDomainName=api.example.com
```

## Backup and Disaster Recovery

### Zone Backup

```shell
# Export zone records for backup
aws route53 list-resource-record-sets --hosted-zone-id Z123456789 > backup.json

# Import zones to different account (disaster recovery)
aws route53 change-resource-record-sets --hosted-zone-id Z987654321 --change-batch file://restore.json
```

### Automated Backups

```shell
# Create backup script
#!/bin/bash
ZONES=$(aws route53 list-hosted-zones --query 'HostedZones[].Id' --output text)
for zone in $ZONES; do
    aws route53 list-resource-record-sets --hosted-zone-id $zone > "backup-${zone//\//_}.json"
done
```

## Support and Resources

- **AWS Route53 Documentation**: https://docs.aws.amazon.com/route53/
- **AWS CLI Reference**: https://docs.aws.amazon.com/cli/latest/reference/route53/
- **IAM Best Practices**: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- **Route53 API Limits**: https://docs.aws.amazon.com/route53/latest/developerguide/DNSLimitations.html

---

**Next Steps**: After setting up AWS Route53, consider configuring [automated DNS management](workflows.md#automation--triggers) or exploring [multi-provider scenarios](multi-provider-scenarios.md).