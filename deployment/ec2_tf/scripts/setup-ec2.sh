#!/bin/bash
# =============================================================================
# EC2 Instance Setup Script using AWS CLI
# This script creates a free-tier EC2 instance without Terraform
# =============================================================================

set -e

# Configuration variables
REGION="${AWS_REGION:-us-west-2}"
INSTANCE_NAME="${INSTANCE_NAME:-flink-playground}"
INSTANCE_TYPE="${INSTANCE_TYPE:-t2.micro}"
KEY_NAME="${KEY_NAME:-flink-playground-key}"
SECURITY_GROUP_NAME="${INSTANCE_NAME}-sg"

echo "======================================"
echo "EC2 Instance Setup Script"
echo "======================================"
echo "Region: $REGION"
echo "Instance Name: $INSTANCE_NAME"
echo "Instance Type: $INSTANCE_TYPE"
echo ""

# Check if AWS CLI is configured
echo "[1/7] Checking AWS CLI configuration..."
if ! aws sts get-caller-identity &>/dev/null; then
    echo "ERROR: AWS CLI is not configured. Run 'aws configure' first."
    exit 1
fi
echo "AWS CLI configured successfully."

# Get the default VPC ID
echo ""
echo "[2/7] Getting default VPC..."
VPC_ID=$(aws ec2 describe-vpcs \
    --region "$REGION" \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
    echo "ERROR: No default VPC found in region $REGION"
    exit 1
fi
echo "Default VPC: $VPC_ID"

# Get a subnet from the default VPC
echo ""
echo "[3/7] Getting subnet..."
SUBNET_ID=$(aws ec2 describe-subnets \
    --region "$REGION" \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "Subnets[0].SubnetId" \
    --output text)
echo "Subnet: $SUBNET_ID"

# Create key pair if it doesn't exist
echo ""
echo "[4/7] Creating SSH key pair..."
if aws ec2 describe-key-pairs --region "$REGION" --key-names "$KEY_NAME" &>/dev/null; then
    echo "Key pair '$KEY_NAME' already exists. Skipping creation."
else
    aws ec2 create-key-pair \
        --region "$REGION" \
        --key-name "$KEY_NAME" \
        --query "KeyMaterial" \
        --output text > "${KEY_NAME}.pem"
    chmod 400 "${KEY_NAME}.pem"
    echo "Key pair created and saved to ${KEY_NAME}.pem"
fi

# Create security group if it doesn't exist
echo ""
echo "[5/7] Creating security group..."
EXISTING_SG=$(aws ec2 describe-security-groups \
    --region "$REGION" \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null || echo "None")

if [ "$EXISTING_SG" != "None" ] && [ -n "$EXISTING_SG" ]; then
    SECURITY_GROUP_ID="$EXISTING_SG"
    echo "Security group already exists: $SECURITY_GROUP_ID"
else
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --region "$REGION" \
        --group-name "$SECURITY_GROUP_NAME" \
        --description "Security group for $INSTANCE_NAME" \
        --vpc-id "$VPC_ID" \
        --query "GroupId" \
        --output text)
    
    # Add SSH inbound rule
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0

    # Add Flink UI inbound rule (port 8081)
    aws ec2 authorize-security-group-ingress \
        --region "$REGION" \
        --group-id "$SECURITY_GROUP_ID" \
        --protocol tcp \
        --port 8081 \
        --cidr 0.0.0.0/0

    echo "Security group created: $SECURITY_GROUP_ID"
fi

# Get the latest Amazon Linux 2023 AMI
echo ""
echo "[6/7] Finding latest Amazon Linux 2023 AMI..."
AMI_ID=$(aws ec2 describe-images \
    --region "$REGION" \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-*-x86_64" \
              "Name=state,Values=available" \
              "Name=virtualization-type,Values=hvm" \
    --query "sort_by(Images, &CreationDate)[-1].ImageId" \
    --output text)
echo "AMI: $AMI_ID"

# Launch the EC2 instance
echo ""
echo "[7/7] Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --region "$REGION" \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-group-ids "$SECURITY_GROUP_ID" \
    --subnet-id "$SUBNET_ID" \
    --associate-public-ip-address \
    --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":8,"VolumeType":"gp3","Encrypted":true,"DeleteOnTermination":true}}]' \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME},{Key=Project,Value=flink-playground},{Key=ManagedBy,Value=aws-cli}]" \
    --user-data '#!/bin/bash
yum update -y
yum install -y docker git java-17-amazon-corretto
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user
echo "Setup complete!"' \
    --query "Instances[0].InstanceId" \
    --output text)

echo "Instance launched: $INSTANCE_ID"

# Wait for the instance to be running
echo ""
echo "Waiting for instance to be running..."
aws ec2 wait instance-running --region "$REGION" --instance-ids "$INSTANCE_ID"

# Get the public IP
PUBLIC_IP=$(aws ec2 describe-instances \
    --region "$REGION" \
    --instance-ids "$INSTANCE_ID" \
    --query "Reservations[0].Instances[0].PublicIpAddress" \
    --output text)

echo ""
echo "======================================"
echo "EC2 Instance Created Successfully!"
echo "======================================"
echo ""
echo "Instance ID:  $INSTANCE_ID"
echo "Public IP:    $PUBLIC_IP"
echo "Key File:     ${KEY_NAME}.pem"
echo ""
echo "Connect using:"
echo "  ssh -i ${KEY_NAME}.pem ec2-user@$PUBLIC_IP"
echo ""
echo "Wait 2-3 minutes for user-data script to complete before connecting."
echo ""

# Save instance info to file
cat > instance-info.txt << EOL
INSTANCE_ID=$INSTANCE_ID
PUBLIC_IP=$PUBLIC_IP
KEY_NAME=$KEY_NAME
SECURITY_GROUP_ID=$SECURITY_GROUP_ID
REGION=$REGION
EOL
echo "Instance info saved to instance-info.txt"
