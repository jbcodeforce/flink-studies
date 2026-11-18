# -----------------------------------------------------------------------------
# Private network path to the DR Enterprise cluster (AWS PrivateLink).
#
#   laptop --SSM--> bastion (private subnet) --> VPC endpoint --> Confluent PLATT
#
# Confluent side : confluent_private_link_attachment (+ _connection)
# AWS side       : VPC, 3 private subnets, SG, interface VPC endpoint,
#                  Route53 private zone with a wildcard record for the PLATT DNS domain
# Egress         : one public subnet + IGW + NAT gateway so the bastion can reach the
#                  SSM service and install tools. The bastion has no public IP.
# -----------------------------------------------------------------------------

# Only regular AZs: without the filters the data source also returns Wavelength zones,
# which support neither NAT gateways nor the Confluent endpoint service.
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-type"
    values = ["availability-zone"]
  }

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# The endpoint service offers a subset of AZs (listed by its PLATT); keep the first 3 that match.
data "aws_vpc_endpoint_service" "confluent" {
  service_name = confluent_private_link_attachment.dr.aws[0].vpc_endpoint_service_name
}

locals {
  azs = slice(
    tolist(setintersection(data.aws_availability_zones.available.names, data.aws_vpc_endpoint_service.confluent.availability_zones)),
    0,
    3,
  )
}

# --- Confluent PrivateLink Attachment ---

resource "confluent_private_link_attachment" "dr" {
  cloud        = "AWS"
  region       = var.dr_region
  display_name = "${var.prefix}-dr-platt"

  environment {
    id = confluent_environment.dr.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --- VPC ---

resource "aws_vpc" "dr" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.prefix}-dr-vpc" }
}

resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.dr.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]

  tags = { Name = "${var.prefix}-dr-private-${local.azs[count.index]}" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.dr.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 100)
  availability_zone       = local.azs[0]
  map_public_ip_on_launch = false

  tags = { Name = "${var.prefix}-dr-public-nat" }
}

resource "aws_internet_gateway" "dr" {
  vpc_id = aws_vpc.dr.id

  tags = { Name = "${var.prefix}-dr-igw" }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = { Name = "${var.prefix}-dr-nat" }
}

resource "aws_nat_gateway" "dr" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id

  depends_on = [aws_internet_gateway.dr]

  tags = { Name = "${var.prefix}-dr-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.dr.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr.id
  }

  tags = { Name = "${var.prefix}-dr-public" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.dr.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dr.id
  }

  tags = { Name = "${var.prefix}-dr-private" }
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security group of the PrivateLink endpoint: only the VPC may reach it ---

resource "aws_security_group" "privatelink" {
  name_prefix = "${var.prefix}-dr-platt-"
  description = "Confluent PrivateLink endpoint: HTTPS and Kafka from inside the VPC only"
  vpc_id      = aws_vpc.dr.id

  ingress {
    description = "HTTPS (Kafka REST, Schema Registry, Flink)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "Kafka"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = { Name = "${var.prefix}-dr-platt-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Interface VPC endpoint to the Confluent endpoint service ---

resource "aws_vpc_endpoint" "confluent" {
  vpc_id              = aws_vpc.dr.id
  vpc_endpoint_type   = "Interface"
  service_name        = confluent_private_link_attachment.dr.aws[0].vpc_endpoint_service_name
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.privatelink.id]
  private_dns_enabled = false

  tags = { Name = "${var.prefix}-dr-platt-endpoint" }
}

resource "confluent_private_link_attachment_connection" "dr" {
  display_name = "${var.prefix}-dr-platt-connection"

  environment {
    id = confluent_environment.dr.id
  }

  aws {
    vpc_endpoint_id = aws_vpc_endpoint.confluent.id
  }

  private_link_attachment {
    id = confluent_private_link_attachment.dr.id
  }

  lifecycle {
    prevent_destroy = false
  }
}

# --- Private DNS: *.<platt dns domain> resolves to the VPC endpoint ---

resource "aws_route53_zone" "platt" {
  name = confluent_private_link_attachment.dr.dns_domain

  vpc {
    vpc_id = aws_vpc.dr.id
  }

  tags = { Name = "${var.prefix}-dr-platt-zone" }
}

resource "aws_route53_record" "platt_wildcard" {
  zone_id = aws_route53_zone.platt.zone_id
  name    = "*.${confluent_private_link_attachment.dr.dns_domain}"
  type    = "CNAME"
  ttl     = 60
  records = [aws_vpc_endpoint.confluent.dns_entry[0].dns_name]
}
