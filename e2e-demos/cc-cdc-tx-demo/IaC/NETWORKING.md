# RDS Networking and Security Configuration

## Finding Which Subnet RDS is Deployed To

RDS uses a **DB Subnet Group** which contains multiple subnets across different availability zones. AWS automatically selects which subnet (and AZ) to deploy the RDS instance to.

### Updating Terraform Outputs

**Important:** Terraform outputs are only available after resources have been created or the state has been refreshed. If you get an error like "Output not found", you need to:

1. **If resources already exist in AWS but outputs are missing:**
   ```bash
   # Refresh Terraform state from AWS
   terraform refresh
   
   # Then view outputs
   terraform output rds_subnet_group_subnet_details
   ```

2. **If you've added new outputs to existing infrastructure:**
   ```bash
   # Apply changes to update outputs (this won't recreate resources)
   terraform apply
   
   # Or use refresh if you just want to update state
   terraform refresh
   ```

3. **If infrastructure hasn't been deployed yet:**
   ```bash
   # Deploy the infrastructure first
   terraform apply
   
   # Then outputs will be available
   terraform output rds_subnet_group_subnet_details
   ```

### Using Terraform Outputs

**Get all potential subnets in the RDS subnet group:**
```bash
# List all subnet IDs in the subnet group
terraform output rds_subnet_group_subnets

# Get detailed information about each subnet
terraform output rds_subnet_group_subnet_details
```

**Get the availability zone where RDS is deployed:**
```bash
terraform output rds_availability_zone
```

### Querying AWS Directly

**Get the actual subnet where RDS is deployed:**
```bash
# Get RDS instance ID
RDS_ID=$(terraform output -raw rds_instance_id)

# Get all active subnets in the DB subnet group
aws rds describe-db-instances --db-instance-identifier $RDS_ID \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[?SubnetStatus==`Active`]' \
  --output table

# Get just the subnet ID where RDS is deployed
aws rds describe-db-instances --db-instance-identifier $RDS_ID \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[?SubnetStatus==`Active`].SubnetIdentifier' \
  --output text

# Get subnet details including CIDR and AZ
aws rds describe-db-instances --db-instance-identifier $RDS_ID \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[?SubnetStatus==`Active`].[SubnetIdentifier,SubnetAvailabilityZone.Name]' \
  --output table
```

**Note:** RDS may show multiple subnets in the subnet group, but the instance itself is deployed to one specific subnet based on the availability zone. The `SubnetStatus` field will show which subnet is "Active" (where the instance is deployed).

### Understanding RDS Subnet Groups

- **DB Subnet Group**: A logical grouping of subnets across multiple AZs
- **RDS Instance**: Deployed to one specific subnet within the subnet group
- **Selection**: AWS automatically selects the subnet based on availability and your configuration
- **Multi-AZ**: If you enable Multi-AZ, RDS will use subnets in different AZs

## Current Security Group Configuration

The RDS instance uses the following security group rules:

### Inbound Rules
- **Port**: 5432 (PostgreSQL)
- **Protocol**: TCP
- **Source**: `0.0.0.0/0` (All IPs - **WARNING: This is open to the internet**)
- **Description**: Allow PostgreSQL inbound traffic

### Outbound Rules
- **Port**: All (0-65535)
- **Protocol**: All
- **Destination**: `0.0.0.0/0`
- **Description**: Allow all outbound traffic

## Common Connection Issues 

### Issue: Connection Timeout

If you're getting connection timeouts, check the following:

#### 1. RDS Public Accessibility

The RDS instance must be in **public subnets** with an **Internet Gateway** to be accessible from outside the VPC.

**Check RDS configuration:**
```bash
terraform output rds_endpoint
aws rds describe-db-instances --db-instance-identifier <instance-id> --query 'DBInstances[0].PubliclyAccessible'
```

**Verify subnet configuration:**
```bash
# Check if subnets have internet gateway routes
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=<vpc-id>" \
  --query 'RouteTables[*].Routes[?GatewayId!=null]'
```

**Find which subnet RDS is deployed to:**
```bash
# Get RDS instance ID
RDS_ID=$(terraform output -raw rds_instance_id)

# Get all subnets in the RDS subnet group (potential subnets)
terraform output rds_subnet_group_subnets

# Get detailed subnet information
terraform output rds_subnet_group_subnet_details

# Get the actual subnet where RDS is deployed (AWS selects this)
aws rds describe-db-instances --db-instance-identifier $RDS_ID \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[?SubnetStatus==`Active`]' \
  --output table

# Get just the subnet ID where RDS is deployed
aws rds describe-db-instances --db-instance-identifier $RDS_ID \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[?SubnetStatus==`Active`].SubnetIdentifier' \
  --output text

# Get availability zone
terraform output rds_availability_zone
```

#### 2. Security Group Rules

Verify the security group is attached and rules are correct:
```bash
# Get security group ID
aws rds describe-db-instances --db-instance-identifier <instance-id> \
  --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text

# Check security group rules
aws ec2 describe-security-groups --group-ids <sg-id>
```

#### 3. Network ACLs

Check if Network ACLs are blocking traffic:
```bash
# Get subnet IDs
aws rds describe-db-instances --db-instance-identifier <instance-id> \
  --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' --output text

# Check Network ACLs for each subnet
aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=<subnet-id>"
```

#### 4. VPC Route Tables

Ensure subnets have routes to Internet Gateway:
```bash
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"
```

**Automatic Validation:**
The Terraform configuration now automatically validates that RDS subnets are associated with route tables that have routes to an Internet Gateway. This validation runs during `terraform plan` and `terraform apply`.

If validation fails, you'll see an error message listing which subnets don't have IGW routes, along with instructions on how to fix them.

## Fixing Missing IGW Routes (Step-by-Step)

If you're getting a validation error about missing IGW routes, follow these steps:

### Step 1: Get Your Information

```bash
cd IaC

# Get VPC ID (from terraform.tfvars or terraform show)
VPC_ID=$(terraform show -json | jq -r '.values.root_module.resources[]? | select(.type=="data.aws_vpc.existing") | .values.id' | head -n1)
echo "VPC ID: $VPC_ID"

# Get IGW ID (from error message or query AWS)
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text)
echo "IGW ID: $IGW_ID"

# Get RDS subnet IDs
SUBNET_IDS=$(terraform output -json rds_subnet_group_subnets 2>/dev/null | jq -r '.[]' || \
    aws rds describe-db-instances --db-instance-identifier $(terraform output -raw rds_instance_id) \
        --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' --output text)
echo "RDS Subnet IDs: $SUBNET_IDS"
```

### Step 2: Find a Route Table with IGW Route (Public Route Table)

```bash
# Find any route table in your VPC that already has an IGW route
PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "RouteTables[?Routes[?GatewayId=='$IGW_ID']].RouteTableId" \
    --output text | head -n1)

if [ -n "$PUBLIC_RT_ID" ] && [ "$PUBLIC_RT_ID" != "None" ]; then
    echo "Found public route table: $PUBLIC_RT_ID"
else
    echo "No route table with IGW route found. We'll add routes to existing route tables."
fi
```

### Step 3: Check Each Subnet

```bash
# For each subnet, check its route table
for SUBNET_ID in $SUBNET_IDS; do
    echo ""
    echo "Checking subnet: $SUBNET_ID"
    
    # Get route table for this subnet
    RT_ID=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
        --query 'RouteTables[0].RouteTableId' \
        --output text)
    
    if [ -z "$RT_ID" ] || [ "$RT_ID" == "None" ]; then
        echo "  ❌ No route table associated"
        if [ -n "$PUBLIC_RT_ID" ]; then
            echo "  → Fix: Associate with public route table"
            echo "    aws ec2 associate-route-table --subnet-id $SUBNET_ID --route-table-id $PUBLIC_RT_ID"
        fi
    else
        echo "  Route Table: $RT_ID"
        
        # Check if it has IGW route
        HAS_IGW=$(aws ec2 describe-route-tables \
            --route-table-ids "$RT_ID" \
            --query "RouteTables[0].Routes[?GatewayId=='$IGW_ID']" \
            --output text)
        
        if [ -z "$HAS_IGW" ] || [ "$HAS_IGW" == "None" ]; then
            echo "  ❌ No IGW route"
            echo "  → Fix: Add IGW route"
            echo "    aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID"
        else
            echo "  ✅ Has IGW route"
        fi
    fi
done
```

### Step 4: Apply the Fixes

**Option A: If subnets need to be associated with a public route table:**
```bash
# Replace <subnet-id> and <route-table-id> with actual values from Step 3
aws ec2 associate-route-table --subnet-id <subnet-id> --route-table-id <route-table-id>
```

**Option B: If route tables need IGW routes added:**
```bash
# Replace <route-table-id> and <igw-id> with actual values
# The IGW ID is shown in the Terraform error message (e.g., igw-0c528b0ad45a9e387)
aws ec2 create-route --route-table-id <route-table-id> \
    --destination-cidr-block 0.0.0.0/0 --gateway-id <igw-id>
```

### Step 5: Verify the Fix

```bash
# Run Terraform plan again - validation should pass
terraform plan

# Test connectivity
RDS_ENDPOINT=$(terraform output -raw rds_address)
nc -zv $RDS_ENDPOINT 5432
```

### Quick Fix Script

For automated fixing, use the provided script:
```bash
cd IaC
./fix-rds-networking.sh
```

This script will:
1. Identify all RDS subnets
2. Check their route table configurations
3. Find or create IGW routes
4. Optionally apply fixes automatically

## Solutions

### Option 1: Use Public Subnets (Current Setup)

**Requirements:**
- RDS must be in subnets with Internet Gateway routes
- `publicly_accessible = true` in terraform.tfvars
- Security group allows your IP (or `0.0.0.0/0` for testing)

**Automatic Validation:**
The Terraform configuration automatically validates that subnets have IGW routes when `db_publicly_accessible = true`. If validation fails, Terraform will show an error with specific subnets that need fixing.

**Verify manually:**
```bash
# Check if subnets are public
aws ec2 describe-subnets --subnet-ids <subnet-id> \
  --query 'Subnets[0].MapPublicIpOnLaunch'

# Check route table associations
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"

# Verify IGW routes exist
aws ec2 describe-route-tables --route-table-ids <route-table-id> \
  --query 'RouteTables[0].Routes[?GatewayId!=null]'
```

**Fix missing IGW routes:**
```bash
# Associate subnet with a route table that has IGW route
aws ec2 associate-route-table --subnet-id <subnet-id> --route-table-id <route-table-id>

# Or add IGW route to existing route table
aws ec2 create-route --route-table-id <route-table-id> \
  --destination-cidr-block 0.0.0.0/0 --gateway-id <igw-id>
```

### Option 2: Restrict Security Group to Your IP

For better security, restrict access to your IP address:

```hcl
# In aws.tf, replace the security group rule:
resource "aws_security_group_rule" "allow_inbound_postgres" {
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  security_group_id = aws_security_group.card_tx_db_sg.id
  cidr_blocks       = ["<your-ip>/32"]  # Replace with your public IP
  description       = "Allow PostgreSQL inbound traffic from my IP"
}
```

**Get your public IP:**
```bash
curl ifconfig.me
```

### Option 3: Use VPC Peering or VPN

For production environments:
- Set up VPC peering between your VPC and Confluent Cloud
- Or use AWS VPN/PrivateLink
- Keep RDS in private subnets
- Update security group to allow Confluent Cloud IP ranges

### Option 4: Use a Bastion Host

Deploy a bastion host in a public subnet:
- Connect to RDS through the bastion
- RDS remains in private subnets
- More secure for production

## Testing Connectivity

### From Your Local Machine

```bash
# Test connection
psql -h <rds-endpoint> -U postgres -d cardtxdb

# Or with connection string
psql "postgresql://postgres:<password>@<rds-endpoint>:5432/cardtxdb"
```

### From Within VPC (EC2 Instance)

If you have an EC2 instance in the same VPC:
```bash
# SSH into EC2 instance
ssh ec2-user@<ec2-ip>

# Test connection
psql -h <rds-endpoint> -U postgres -d cardtxdb
```

### Troubleshooting Commands

```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier <instance-id> \
  --query 'DBInstances[0].[DBInstanceStatus,PubliclyAccessible,Endpoint.Address]'

# Test port connectivity (from your machine)
nc -zv <rds-endpoint> 5432

# Check security group
aws ec2 describe-security-groups --group-ids <sg-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

## Security Recommendations

1. **Restrict Security Group**: Don't use `0.0.0.0/0` in production
2. **Use Private Subnets**: Keep RDS in private subnets when possible
3. **Enable Encryption**: RDS encryption at rest and in transit
4. **Use VPC Peering**: For Confluent Cloud connectivity
5. **Monitor Access**: Enable CloudTrail and VPC Flow Logs

## For Confluent Cloud CDC Connector

The CDC connector needs to reach RDS. Options:

1. **Public RDS** (current setup): Connector connects via public endpoint
2. **VPC Peering**: Set up peering between Confluent Cloud and your VPC
3. **PrivateLink**: Use AWS PrivateLink for private connectivity

See [Confluent Cloud Networking Documentation](https://docs.confluent.io/cloud/current/networking/overview.html) for details.
