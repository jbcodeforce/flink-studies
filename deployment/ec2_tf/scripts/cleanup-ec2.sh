#!/bin/bash
# =============================================================================
# EC2 Instance Cleanup Script using AWS CLI
# This script removes resources created by setup-ec2.sh
# =============================================================================

set -e

# Configuration variables
REGION="${AWS_REGION:-us-east-1}"
INSTANCE_NAME="${INSTANCE_NAME:-flink-playground}"
KEY_NAME="${KEY_NAME:-flink-playground-key}"
SECURITY_GROUP_NAME="${INSTANCE_NAME}-sg"

echo "======================================"
echo "EC2 Instance Cleanup Script"
echo "======================================"
echo "Region: $REGION"
echo "Instance Name: $INSTANCE_NAME"
echo ""

# Load instance info if available
if [ -f "instance-info.txt" ]; then
    source instance-info.txt
    echo "Loaded instance info from file."
fi

# Find instance by name if not in file
if [ -z "$INSTANCE_ID" ]; then
    echo "Looking for instance by name tag..."
    INSTANCE_ID=$(aws ec2 describe-instances \
        --region "$REGION" \
        --filters "Name=tag:Name,Values=$INSTANCE_NAME" "Name=instance-state-name,Values=running,stopped,pending" \
        --query "Reservations[0].Instances[0].InstanceId" \
        --output text 2>/dev/null || echo "None")
fi

# Terminate instance
echo ""
echo "[1/3] Terminating EC2 instance..."
if [ "$INSTANCE_ID" != "None" ] && [ -n "$INSTANCE_ID" ]; then
    aws ec2 terminate-instances --region "$REGION" --instance-ids "$INSTANCE_ID" &>/dev/null || true
    echo "Terminating instance: $INSTANCE_ID"
    echo "Waiting for instance to terminate..."
    aws ec2 wait instance-terminated --region "$REGION" --instance-ids "$INSTANCE_ID" 2>/dev/null || true
    echo "Instance terminated."
else
    echo "No running instance found with name '$INSTANCE_NAME'"
fi

# Delete security group
echo ""
echo "[2/3] Deleting security group..."
SECURITY_GROUP_ID=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

if [ "$SECURITY_GROUP_ID" != "None" ] && [ -n "$SECURITY_GROUP_ID" ]; then
    # Wait a bit for ENIs to be deleted
    sleep 5
    aws ec2 delete-security-group --region "$REGION" --group-id "$SECURITY_GROUP_ID" 2>/dev/null || echo "Security group may still be in use. Try again in a few minutes."
    echo "Security group deleted: $SECURITY_GROUP_ID"
else
    echo "Security group '$SECURITY_GROUP_NAME' not found."
fi

# Delete key pair
echo ""
echo "[3/3] Deleting key pair..."
if aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" &>/dev/null; then
    aws ec2 delete-key-pair --region "$REGION" --key-name "$KEY_NAME"
    echo "Key pair deleted: $KEY_NAME"
else
    echo "Key pair '$KEY_NAME' not found."
fi

# Remove local files
echo ""
echo "Cleaning up local files..."
rm -f "${KEY_NAME}.pem" instance-info.txt 2>/dev/null || true

echo ""
echo "======================================"
echo "Cleanup Complete!"
echo "======================================"
