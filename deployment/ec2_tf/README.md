# EC2 Playground Setup

This guide helps you create a free-tier EC2 instance on AWS for Flink experiments. Choose between **Terraform** (recommended) or **AWS CLI** scripts.

## Prerequisites

### 1. Install Required Tools

**On macOS (using Homebrew):**

```bash
# Install Terraform
brew install terraform

# Install AWS CLI
brew install awscli
```

**On Linux:**

```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. Configure AWS Credentials

Run `aws configure` and enter your credentials:

```bash
aws configure
```

You will be prompted for:

- **AWS Access Key ID**: Your access key
- **AWS Secret Access Key**: Your secret key
- **Default region**: `us-west-2` (recommended for free tier)
- **Output format**: `yaml`

To get AWS credentials:

1. Log in to [AWS Console](https://console.aws.amazon.com/)
2. Go to **IAM** > **Users** > **Your User** > **Security credentials**
3. Click **Create access key**

### 3. Verify Configuration

```bash
# Check AWS CLI is configured
aws sts get-caller-identity

# Check Terraform is installed
terraform version
```

## Option 1: Terraform (Recommended)

Terraform provides infrastructure as code with state management and easy cleanup.

### Quick Start

```bash
cd deployment/ec2_tf

# Initialize Terraform
terraform init

# Preview what will be created
terraform plan

# Create the infrastructure
terraform apply
```

Type `yes` when prompted to confirm.

### What Gets Created

| Resource | Description |
|----------|-------------|
| EC2 Instance | t2.micro (free-tier) with Amazon Linux 2023 |
| Security Group | SSH (port 22) and Flink UI (port 8081) access |
| SSH Key Pair | Auto-generated, saved as `.pem` file |

### Connect to Your Instance

After `terraform apply` completes:

```bash
# Terraform shows the SSH command in output
# Or use the connect script:
./scripts/connect.sh

# Or manually:
ssh -i flink-playground-key.pem ec2-user@<PUBLIC_IP>
```

The public IP is shown in the terraform output.

### Customize Settings

Copy the example variables file and edit as needed:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
aws_region       = "us-east-1"     # Your preferred region
instance_name    = "my-flink-dev"  # Custom instance name
instance_type    = "t2.micro"      # Keep this for free tier
allowed_ssh_cidr = "1.2.3.4/32"    # Your IP for security
```

To find your IP address:

```bash
curl -s ifconfig.me
```

### Cleanup Resources

When finished, destroy all resources:

```bash
terraform destroy
```

Type `yes` to confirm. This removes the instance, security group, and key pair.

## Option 2: AWS CLI Scripts

For those who prefer shell scripts over Terraform.

### Quick Start

```bash
cd deployment/ec2_tf/scripts

# Make scripts executable
chmod +x *.sh

# Create the EC2 instance
./setup-ec2.sh
```

### Connect to Instance

```bash
# Use the connect script
./connect.sh

# Or manually (check instance-info.txt for IP)
ssh -i flink-playground-key.pem ec2-user@<PUBLIC_IP>
```

### Cleanup Resources

```bash
./cleanup-ec2.sh
```

## After Connecting to the Instance

The instance comes with Docker, Git, and Java 17 pre-installed.

### Verify Setup

```bash
# Check Docker
docker --version

# Check Java
java -version

# Check disk space
df -h
```

### Install Flink

```bash
# Download Flink
export FLINK_VERSION=1.20.3
wget https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/flink-${FLINK_VERSION}-bin-scala_2.12.tgz
tar -xzf flink-${FLINK_VERSION}-bin-scala_2.12.tgz
cd flink-${FLINK_VERSION}

# Start local cluster
./bin/start-cluster.sh
```

Access the Flink Web UI at `http://<PUBLIC_IP>:8081`

## Cost Information

This setup uses **free-tier eligible** resources:

| Resource | Free Tier Limit |
|----------|-----------------|
| t2.micro | 750 hours/month (first 12 months) |
| EBS Storage | 30 GB/month |
| Data Transfer | 1 GB/month outbound |

To avoid charges:

- Destroy resources when not in use
- Stay within a single region
- Monitor usage in AWS Cost Explorer

## Troubleshooting

### Cannot SSH to Instance

1. Wait 2-3 minutes after creation for user-data script to complete
2. Check security group allows your IP
3. Verify key file permissions: `chmod 400 *.pem`

### Permission Denied (publickey)

```bash
# Ensure correct permissions
chmod 400 flink-playground-key.pem

# Use correct username
ssh -i flink-playground-key.pem ec2-user@<IP>  # NOT root or ubuntu
```

### Verify EC2 access

* Verify the flink/conf/config.yaml has the following changes:
    ```yaml
    rest:
        address: 0.0.0.0
        bind-address: 0.0.0.0
        port: 8081
    ```
* In EC2:
    ```sh
    # Verify exposed port
    ss -tlnp | grep 8081
    ```

### Terraform State Issues

```bash
# Reset local state
rm -rf .terraform terraform.tfstate*
terraform init
```

### Security Group Already Exists

If you get an error about duplicate security group:

```bash
# List security groups
aws ec2 describe-security-groups --filters "Name=group-name,Values=flink-playground-sg"

# Delete if needed
aws ec2 delete-security-group --group-id <GROUP_ID>
```

## File Structure

```
ec2_tf/
├── main.tf                    # Main Terraform configuration
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── providers.tf               # AWS provider configuration
├── terraform.tfvars.example   # Example variables file
├── .gitignore                 # Git ignore patterns
├── README.md                  # This documentation
└── scripts/
    ├── setup-ec2.sh           # AWS CLI setup script
    ├── cleanup-ec2.sh         # AWS CLI cleanup script
    └── connect.sh             # Quick SSH connection script
```

## Security Recommendations

For production use:

1. **Restrict SSH access** to your IP only in `terraform.tfvars`:

   ```hcl
   allowed_ssh_cidr = "YOUR_IP/32"
   ```

2. **Use IAM roles** instead of long-term credentials

3. **Enable VPC Flow Logs** for network monitoring

4. **Use Session Manager** instead of SSH for access without open ports
