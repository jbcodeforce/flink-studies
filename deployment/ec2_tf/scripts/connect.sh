#!/bin/bash
# =============================================================================
# Quick SSH Connection Script
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for key file in parent directory (Terraform creates it there)
KEY_FILE=$(find "$PARENT_DIR" -maxdepth 1 -name "*.pem" -type f | head -1)

# If not found, check current directory
if [ -z "$KEY_FILE" ]; then
    KEY_FILE=$(find "$SCRIPT_DIR" -maxdepth 1 -name "*.pem" -type f | head -1)
fi

if [ -z "$KEY_FILE" ]; then
    echo "ERROR: No .pem key file found."
    echo "Run terraform apply first, or use setup-ec2.sh"
    exit 1
fi

# Try to get IP from terraform output
if [ -f "$PARENT_DIR/terraform.tfstate" ]; then
    cd "$PARENT_DIR"
    PUBLIC_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")
    cd - > /dev/null
fi

# If not found, try instance-info.txt
if [ -z "$PUBLIC_IP" ] && [ -f "$SCRIPT_DIR/instance-info.txt" ]; then
    source "$SCRIPT_DIR/instance-info.txt"
fi

if [ -z "$PUBLIC_IP" ]; then
    echo "ERROR: Could not determine instance IP address."
    echo "Check terraform output or instance-info.txt"
    exit 1
fi

echo "Connecting to ec2-user@$PUBLIC_IP..."
ssh -i "$KEY_FILE" -o StrictHostKeyChecking=accept-new ec2-user@"$PUBLIC_IP"
