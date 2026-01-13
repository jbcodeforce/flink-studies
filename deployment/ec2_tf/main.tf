# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Get the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Get the latest Amazon Linux 2023 AMI (free-tier eligible)
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# -----------------------------------------------------------------------------
# SSH Key Pair
# -----------------------------------------------------------------------------

# Generate a new SSH private key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "this" {
  key_name   = var.key_name
  public_key = tls_private_key.ssh.public_key_openssh
}

# Save the private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_pem
  filename        = "${path.module}/${var.key_name}.pem"
  file_permission = "0400"
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "ec2" {
  name        = "${var.instance_name}-sg"
  description = "Security group for ${var.instance_name} EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  tags = {
    Name = "${var.instance_name}-sg"
  }
}

# Allow SSH inbound
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow SSH access"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

# Allow Flink Web UI (optional)
resource "aws_vpc_security_group_ingress_rule" "flink_ui" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow Flink Web UI access"
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 8081
  to_port           = 8081
  ip_protocol       = "tcp"
}

# Allow all outbound traffic
resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow all outbound traffic"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# -----------------------------------------------------------------------------
# EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "this" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.this.key_name
  vpc_security_group_ids = [aws_security_group.ec2.id]
  subnet_id              = data.aws_subnets.default.ids[0]

  # Enable public IP for SSH access
  associate_public_ip_address = true

  # Root volume configuration (8GB is free-tier eligible)
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  # User data script to install basic tools
  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker git java-17-amazon-corretto
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ec2-user
    echo "Setup complete!"
  EOF

  tags = {
    Name = var.instance_name
  }
}
