# Quick Fix: RDS Subnet IGW Routes

If you're getting a Terraform validation error about missing IGW routes, use these commands to fix it quickly.

## Your IGW ID

From the error message, your IGW ID is: `igw-0c528b0ad45a9e387`

## Quick Fix Commands

Run these commands in order:

### 1. Get RDS Subnet IDs

```bash
cd IaC

# Option 1: From Terraform outputs (if available)
terraform output -json rds_subnet_group_subnets | jq -r '.[]'

# Option 2: From AWS directly
RDS_ID=$(terraform output -raw rds_instance_id)
aws rds describe-db-instances --db-instance-identifier $RDS_ID \
    --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' \
    --output text
```

### 2. For Each Subnet, Check and Fix Route Table

Replace `<subnet-id>` with each subnet ID from step 1:

```bash
# Get the route table for this subnet
RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=association.subnet-id,Values=<subnet-id>" \
    --query 'RouteTables[0].RouteTableId' \
    --output text)

echo "Subnet <subnet-id> uses route table: $RT_ID"

# Check if it has IGW route
aws ec2 describe-route-tables --route-table-ids $RT_ID \
    --query 'RouteTables[0].Routes[?GatewayId!=null]' \
    --output table

# If no IGW route, add it:
aws ec2 create-route --route-table-id $RT_ID \
    --destination-cidr-block 0.0.0.0/0 \
    --gateway-id igw-0c528b0ad45a9e387
```

### 3. One-Liner to Fix All Subnets

```bash
# Set your IGW ID
IGW_ID="igw-0c528b0ad45a9e387"

# Get all RDS subnet IDs
SUBNET_IDS=$(terraform output -json rds_subnet_group_subnets 2>/dev/null | jq -r '.[]' || \
    aws rds describe-db-instances --db-instance-identifier $(terraform output -raw rds_instance_id) \
        --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' --output text)

# Fix each subnet
for SUBNET_ID in $SUBNET_IDS; do
    echo "Processing subnet: $SUBNET_ID"
    
    # Get route table
    RT_ID=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$SUBNET_ID" \
        --query 'RouteTables[0].RouteTableId' \
        --output text)
    
    if [ -n "$RT_ID" ] && [ "$RT_ID" != "None" ]; then
        # Check if IGW route exists
        HAS_IGW=$(aws ec2 describe-route-tables --route-table-ids "$RT_ID" \
            --query "RouteTables[0].Routes[?GatewayId=='$IGW_ID']" \
            --output text)
        
        if [ -z "$HAS_IGW" ] || [ "$HAS_IGW" == "None" ]; then
            echo "  Adding IGW route to route table $RT_ID..."
            aws ec2 create-route --route-table-id "$RT_ID" \
                --destination-cidr-block 0.0.0.0/0 \
                --gateway-id "$IGW_ID" || echo "  Route may already exist"
        else
            echo "  ✅ Already has IGW route"
        fi
    else
        echo "  ⚠️  No route table found for subnet $SUBNET_ID"
    fi
done
```

### 4. Verify the Fix

```bash
# Terraform validation should now pass
terraform plan

# Test connectivity
RDS_ENDPOINT=$(terraform output -raw rds_address)
nc -zv $RDS_ENDPOINT 5432
```

## Alternative: Use the Fix Script

```bash
cd IaC
./fix-rds-networking.sh
```

The script will automatically:
- Detect your VPC and IGW
- Find all RDS subnets
- Check route table configurations
- Apply fixes interactively

## Still Having Issues?

1. **Check if subnets are associated with route tables:**
   ```bash
   aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=<subnet-id>"
   ```

2. **If no route table is associated, find a public route table:**
   ```bash
   VPC_ID=$(terraform show -json | jq -r '.values.root_module.resources[]? | select(.type=="data.aws_vpc.existing") | .values.id' | head -n1)
   aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" \
       --query "RouteTables[?Routes[?GatewayId=='igw-0c528b0ad45a9e387']].RouteTableId" \
       --output text
   ```

3. **Associate subnet with public route table:**
   ```bash
   aws ec2 associate-route-table --subnet-id <subnet-id> --route-table-id <public-rt-id>
   ```

See [NETWORKING.md](./NETWORKING.md) for detailed troubleshooting.
