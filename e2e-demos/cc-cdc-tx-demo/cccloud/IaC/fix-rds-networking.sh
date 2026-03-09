#!/bin/bash
# Fix RDS Subnet IGW Routes
# This script diagnoses and fixes missing Internet Gateway routes for RDS subnets

set -e

echo "=========================================="
echo "RDS Networking Diagnostic and Fix Script"
echo "=========================================="
echo ""

# Get VPC ID from Terraform
cd "$(dirname "$0")"
VPC_ID=$(terraform show -json 2>/dev/null | jq -r '.values.root_module.resources[]? | select(.type=="data.aws_vpc.existing") | .values.id // empty' | head -n1)

if [ -z "$VPC_ID" ]; then
    # Try to get from terraform.tfvars
    if [ -f "terraform.tfvars" ]; then
        # Extract VPC ID from terraform.tfvars using awk to handle quotes properly
        # Pattern: existing_vpc_id = "vpc-xxx"  # comment
        VPC_ID=$(grep -E '^\s*existing_vpc_id\s*=' terraform.tfvars | awk -F'"' '{print $2}' | head -n1)
    fi
fi

# Final cleanup - remove any remaining whitespace
if [ -n "$VPC_ID" ]; then
    VPC_ID=$(echo "$VPC_ID" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
fi

if [ -z "$VPC_ID" ]; then
    echo "ERROR: Could not determine VPC ID. Please run 'terraform refresh' first."
    exit 1
fi

echo "VPC ID: $VPC_ID"
echo ""

# Get IGW ID
IGW_ID=$(aws ec2 describe-internet-gateways \
    --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
    --query 'InternetGateways[0].InternetGatewayId' \
    --output text)

if [ -z "$IGW_ID" ] || [ "$IGW_ID" == "None" ]; then
    echo "ERROR: No Internet Gateway found in VPC $VPC_ID"
    echo "Please create and attach an Internet Gateway first."
    exit 1
fi

echo "Internet Gateway ID: $IGW_ID"
echo ""

# Get RDS subnet group subnets
echo "Getting RDS subnet group information..."
SUBNET_IDS=""

# Try to get from Terraform outputs first
if terraform output -json rds_subnet_group_subnets >/dev/null 2>&1; then
    SUBNET_IDS=$(terraform output -json rds_subnet_group_subnets 2>/dev/null | jq -r '.[]' 2>/dev/null || echo "")
fi

# If that failed, try to get from RDS instance directly
if [ -z "$SUBNET_IDS" ]; then
    echo "WARNING: Could not get subnet IDs from Terraform outputs."
    echo "Trying to get from RDS instance directly..."
    RDS_ID=""
    if terraform output -raw rds_instance_id >/dev/null 2>&1; then
        RDS_ID=$(terraform output -raw rds_instance_id 2>/dev/null || echo "")
    fi
    
    if [ -n "$RDS_ID" ] && [ "$RDS_ID" != "" ]; then
        SUBNET_IDS=$(aws rds describe-db-instances --db-instance-identifier "$RDS_ID" \
            --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' \
            --output text 2>/dev/null || echo "")
    fi
fi

if [ -z "$SUBNET_IDS" ] || [ "$SUBNET_IDS" == "" ]; then
    echo "ERROR: Could not determine RDS subnet IDs."
    echo "Please ensure RDS is deployed and run 'terraform refresh'"
    exit 1
fi

echo "RDS Subnet IDs:"
# Handle both space-separated and newline-separated subnet IDs
echo "$SUBNET_IDS" | tr ' \t' '\n' | grep -v '^$' | while read -r subnet_id; do
    if [ -n "$subnet_id" ]; then
        echo "  - $subnet_id"
    fi
done
echo ""

# Find a route table with IGW route (public route table)
echo "Looking for route table with IGW route..."
PUBLIC_RT_ID=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "RouteTables[?Routes[?GatewayId=='$IGW_ID']].RouteTableId" \
    --output text | head -n1)

if [ -z "$PUBLIC_RT_ID" ] || [ "$PUBLIC_RT_ID" == "None" ]; then
    echo "WARNING: No route table found with IGW route."
    echo "We'll need to add IGW routes to the subnets' route tables."
    PUBLIC_RT_ID=""
else
    echo "Found public route table: $PUBLIC_RT_ID"
fi
echo ""

# Check each subnet
echo "Checking each subnet's route table configuration..."
echo ""

FIXES_NEEDED=0

# Convert subnet IDs to array, handling both space and newline separators
# Read into array safely
SUBNET_ARRAY=()
while IFS= read -r line; do
    if [ -n "$line" ]; then
        SUBNET_ARRAY+=("$line")
    fi
done < <(echo "$SUBNET_IDS" | tr ' \t' '\n' | grep -v '^$')

if [ ${#SUBNET_ARRAY[@]} -eq 0 ]; then
    echo "ERROR: No subnet IDs found to process."
    exit 1
fi

for subnet_id in "${SUBNET_ARRAY[@]}"; do
    echo "Subnet: $subnet_id"
    
    # Get route table for this subnet
    RT_ID=$(aws ec2 describe-route-tables \
        --filters "Name=association.subnet-id,Values=$subnet_id" \
        --query 'RouteTables[0].RouteTableId' \
        --output text)
    
    if [ -z "$RT_ID" ] || [ "$RT_ID" == "None" ]; then
        echo "  ❌ No route table associated"
        FIXES_NEEDED=$((FIXES_NEEDED + 1))
        
        if [ -n "$PUBLIC_RT_ID" ]; then
            echo "  → Fix: Associate with public route table"
            echo "    aws ec2 associate-route-table --subnet-id $subnet_id --route-table-id $PUBLIC_RT_ID"
        else
            echo "  → Fix: Need to find or create a route table with IGW route first"
        fi
    else
        echo "  Route Table: $RT_ID"
        
        # Check if route table has IGW route
        HAS_IGW=$(aws ec2 describe-route-tables \
            --route-table-ids "$RT_ID" \
            --query "RouteTables[0].Routes[?GatewayId=='$IGW_ID']" \
            --output text)
        
        if [ -z "$HAS_IGW" ] || [ "$HAS_IGW" == "None" ]; then
            echo "  ❌ No IGW route found"
            FIXES_NEEDED=$((FIXES_NEEDED + 1))
            echo "  → Fix: Add IGW route to route table"
            echo "    aws ec2 create-route --route-table-id $RT_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID"
        else
            echo "  ✅ Has IGW route"
        fi
    fi
    echo ""
done

echo "=========================================="
if [ $FIXES_NEEDED -eq 0 ]; then
    echo "✅ All subnets have IGW routes configured correctly!"
    echo ""
    echo "If you still can't connect, check:"
    echo "  1. Security group rules allow your IP"
    echo "  2. RDS is publicly accessible: terraform output -raw rds_endpoint"
    echo "  3. Network ACLs are not blocking traffic"
else
    echo "⚠️  Found $FIXES_NEEDED subnet(s) that need fixing"
    echo ""
    echo "Would you like to apply the fixes automatically? (y/n)"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Applying fixes..."
        echo ""
        
        for subnet_id in "${SUBNET_ARRAY[@]}"; do
            RT_ID=$(aws ec2 describe-route-tables \
                --filters "Name=association.subnet-id,Values=$subnet_id" \
                --query 'RouteTables[0].RouteTableId' \
                --output text)
            
            if [ -z "$RT_ID" ] || [ "$RT_ID" == "None" ]; then
                if [ -n "$PUBLIC_RT_ID" ]; then
                    echo "Associating subnet $subnet_id with public route table $PUBLIC_RT_ID..."
                    aws ec2 associate-route-table --subnet-id "$subnet_id" --route-table-id "$PUBLIC_RT_ID"
                else
                    echo "ERROR: No public route table found. Cannot auto-fix subnet $subnet_id"
                fi
            else
                HAS_IGW=$(aws ec2 describe-route-tables \
                    --route-table-ids "$RT_ID" \
                    --query "RouteTables[0].Routes[?GatewayId=='$IGW_ID']" \
                    --output text)
                
                if [ -z "$HAS_IGW" ] || [ "$HAS_IGW" == "None" ]; then
                    echo "Adding IGW route to route table $RT_ID for subnet $subnet_id..."
                    aws ec2 create-route --route-table-id "$RT_ID" --destination-cidr-block 0.0.0.0/0 --gateway-id "$IGW_ID" || echo "Route may already exist"
                fi
            fi
        done
        
        echo ""
        echo "✅ Fixes applied! Please verify:"
        echo "  terraform plan  # Should pass validation now"
        echo "  nc -zv \$(terraform output -raw rds_address) 5432  # Test connectivity"
    else
        echo ""
        echo "Manual fix commands are shown above. Run them individually to fix the issue."
    fi
fi

echo ""
echo "=========================================="
