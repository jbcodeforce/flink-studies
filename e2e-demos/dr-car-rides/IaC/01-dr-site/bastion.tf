# -----------------------------------------------------------------------------
# Bastion — the only host that reaches the DR private endpoint.
#
# Runs: Layer 2 apply, the DR producer, DR loss sampling, and dbt for DR when the
# Flink API needs the private endpoint.
#
# Hardening: no public IP, no SSH, no inbound rules, IMDSv2 required, encrypted
# root volume. Access only through AWS Systems Manager Session Manager.
# -----------------------------------------------------------------------------

data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

data "aws_iam_policy_document" "bastion_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name_prefix        = "${var.prefix}-dr-bastion-"
  assume_role_policy = data.aws_iam_policy_document.bastion_assume.json
}

resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read-only access to ONE Parameter Store path: how the bastion receives the IaC outputs
# (API keys). The parameter is written by scripts/push-outputs.sh, not by Terraform, so the
# secrets are not duplicated in this layer's state. Default AWS-managed key (aws/ssm).
data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "bastion_outputs" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:${var.dr_region}:${data.aws_caller_identity.current.account_id}:parameter${var.outputs_parameter_name}"]
  }
}

resource "aws_iam_role_policy" "bastion_outputs" {
  name_prefix = "read-iac-outputs-"
  role        = aws_iam_role.bastion.id
  policy      = data.aws_iam_policy_document.bastion_outputs.json
}

resource "aws_iam_instance_profile" "bastion" {
  name_prefix = "${var.prefix}-dr-bastion-"
  role        = aws_iam_role.bastion.name
}

# No ingress rules at all: Session Manager uses an outbound connection.
resource "aws_security_group" "bastion" {
  name_prefix = "${var.prefix}-dr-bastion-"
  description = "Bastion: no inbound, outbound HTTPS and Kafka only"
  vpc_id      = aws_vpc.dr.id

  egress {
    description = "HTTPS (SSM, package installs, PrivateLink REST/SR/Flink)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Kafka over the PrivateLink endpoint"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "DNS (VPC resolver)"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.prefix}-dr-bastion-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.bastion_instance_type
  subnet_id                   = aws_subnet.private[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = false

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # IMDSv2 only
  }

  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  tags = { Name = "${var.prefix}-dr-bastion" }

  # Needs egress (NAT) and DNS (private zone) before it is useful.
  depends_on = [
    aws_route_table_association.private,
    aws_route53_record.platt_wildcard,
  ]
}
