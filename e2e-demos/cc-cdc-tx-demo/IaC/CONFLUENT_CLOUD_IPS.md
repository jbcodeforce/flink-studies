# Confluent Cloud IP Addresses for RDS Security Group

## Overview

Confluent Cloud connectors need to connect to your RDS PostgreSQL instance. To allow this securely, you need to add Confluent Cloud's egress IP addresses to your RDS security group.

## How to Get the Latest IP Addresses

1. Go to your Confluent Cloud environment
2. Navigate to **Connectors**
3. Select your CDC connector
4. Go to **Networking** or **Configuration** tab
5. Look for **Egress IPs** or **Source IPs**
6. Copy the list of IP addresses


## Configuration

### Option 1: Use Default List (Recommended for Testing)

The default configuration includes common Confluent Cloud connector egress IPs. These are automatically added to your security group:

```hcl
# In terraform.tfvars - no need to specify, defaults are used
# confluent_cloud_cidr_blocks is already set in variables.tf
```

### Option 2: Override with Your Specific IPs

If you have the exact IP addresses from your Confluent Cloud environment:

```hcl
# In terraform.tfvars
confluent_cloud_cidr_blocks = [
  "35.80.209.50/32",
  "35.81.13.52/32",
  "44.224.191.248/32",
  # ... add all your Confluent Cloud IPs here
]
```

### Option 3: Add Your Own IPs for Direct Access

You can also add your own IP addresses for direct database access:

```hcl
# In terraform.tfvars
# Get your IP: curl ifconfig.me
db_allowed_cidr_blocks = ["<your-ip>/32"]  # e.g., ["203.0.113.0/32"]
```

## Security Group Configuration

The security group rule combines:
- **Confluent Cloud IPs** (from `confluent_cloud_cidr_blocks`)
- **Your IPs** (from `db_allowed_cidr_blocks`)

**Example:**
```hcl
# Security group will allow:
# - All Confluent Cloud connector IPs (for CDC)
# - Your specific IP (for direct access)
confluent_cloud_cidr_blocks = [...]  # Auto-included
db_allowed_cidr_blocks = ["73.189.157.48/32"]  # Your IP
```

## Important Notes

1. **Never use `0.0.0.0/0` in production** - This allows access from anywhere on the internet
2. **Update IPs regularly** - Confluent Cloud IPs may change, check periodically
3. **Region-specific** - IPs may vary by Confluent Cloud region
4. **Verify connectivity** - After updating security groups, test the CDC connector

## Troubleshooting

### Connector Cannot Connect to RDS

1. **Check security group rules:**
   ```bash
   aws ec2 describe-security-groups --group-ids <sg-id> \
     --query 'SecurityGroups[0].IpPermissions'
   ```

2. **Verify Confluent Cloud IPs are included:**
   ```bash
   terraform output -json | jq '.confluent_cloud_cidr_blocks.value'
   ```

3. **Test connectivity from Confluent Cloud:**
   - Check connector logs in Confluent Cloud UI
   - Look for connection timeout or "connection refused" errors

### Updating IP Addresses

If Confluent Cloud IPs change:

1. Update `confluent_cloud_cidr_blocks` in `terraform.tfvars`
2. Apply changes:
   ```bash
   terraform apply -target=aws_security_group_rule.allow_inbound_postgres
   ```

## Alternative: VPC Peering or PrivateLink

For production environments, consider:
- **VPC Peering** between Confluent Cloud and your AWS VPC
- **AWS PrivateLink** for private connectivity
- This eliminates the need for public IP allowlists

See [Confluent Cloud Networking Documentation](https://docs.confluent.io/cloud/current/networking/overview.html) for details.
