# -----------------------------------------------------------------------------
# ML Inference Infrastructure (ECS/Fargate)
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

locals {
  cpu_architecture = var.local_architecture == "arm64" || var.local_architecture == "aarch64" ? "ARM64" : "X86_64"
  
  # Determine if HTTP should redirect to HTTPS
  http_redirect_to_https = var.enable_ml_inference_alb && var.ml_inference_certificate_arn != "" && var.ml_inference_redirect_http_to_https
}

# -----------------------------------------------------------------------------
# Security Group for ECS
# -----------------------------------------------------------------------------
resource "aws_security_group" "card_tx_ecs_sg" {
  name        = "${var.prefix}-ecs-sg-${random_id.env_display_id.hex}"
  description = "Security group for Card TX ML Inference ECS tasks"
  vpc_id      = data.aws_vpc.existing.id

  # HTTP ingress - allow from ALB if enabled, otherwise from anywhere
  dynamic "ingress" {
    for_each = var.enable_ml_inference_alb ? [] : [1]
    content {
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP API for ML inference (direct access)"
    }
  }

  # HTTPS ingress - only when ALB is not enabled
  dynamic "ingress" {
    for_each = var.enable_ml_inference_alb ? [] : [1]
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS API for ML inference (direct access)"
    }
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.prefix}-ecs-sg"
  }
}

# -----------------------------------------------------------------------------
# ECR Repository for ML Inference Container
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "card_tx_ml_inference_repo" {
  name                 = "${var.prefix}-ml-inference-${random_id.env_display_id.hex}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.prefix}-ml-inference-repo"
  }

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# ECS Cluster
# -----------------------------------------------------------------------------
resource "aws_ecs_cluster" "card_tx_ecs_cluster" {
  name = "${var.prefix}-ecs-cluster-${random_id.env_display_id.hex}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.prefix}-ecs-cluster"
  }
}

# -----------------------------------------------------------------------------
# IAM Roles for ECS
# -----------------------------------------------------------------------------

# Task Execution Role (for pulling images, logging)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.prefix}-ecs-task-execution-role-${random_id.env_display_id.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-ecs-task-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task Role (for container runtime permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.prefix}-ecs-task-role-${random_id.env_display_id.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.prefix}-ecs-task-role"
  }
}

# Allow task to access S3 for model artifacts
resource "aws_iam_role_policy" "ecs_task_s3_policy" {
  name = "${var.prefix}-ecs-task-s3-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.card_tx_iceberg.arn,
          "${aws_s3_bucket.card_tx_iceberg.arn}/*"
        ]
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "card_tx_ml_inference_logs" {
  name              = "/ecs/${var.prefix}-ml-inference-${random_id.env_display_id.hex}"
  retention_in_days = 14

  tags = {
    Name = "${var.prefix}-ml-inference-logs"
  }
}

# -----------------------------------------------------------------------------
# ECS Task Definition
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "card_tx_ml_inference_task" {
  family                   = "${var.prefix}-ml-inference-task-${random_id.env_display_id.hex}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  cpu                      = "512"
  memory                   = "1024"

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = local.cpu_architecture
  }

  container_definitions = jsonencode([
    {
      name      = "ml-inference"
      image     = var.ml_inference_image != "" ? var.ml_inference_image : "${aws_ecr_repository.card_tx_ml_inference_repo.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "APP_ENV"
          value = "production"
        },
        {
          name  = "LOG_LEVEL"
          value = "INFO"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.card_tx_ml_inference_logs.name
          "awslogs-region"        = var.cloud_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8080/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = {
    Name = "${var.prefix}-ml-inference-task"
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer (Optional)
# -----------------------------------------------------------------------------

# Security Group for ALB
resource "aws_security_group" "card_tx_alb_sg" {
  count       = var.enable_ml_inference_alb ? 1 : 0
  name        = "${var.prefix}-alb-sg-${random_id.env_display_id.hex}"
  description = "Security group for ML Inference Application Load Balancer"
  vpc_id      = data.aws_vpc.existing.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "${var.prefix}-alb-sg"
  }
}

# Application Load Balancer
resource "aws_lb" "card_tx_ml_inference_alb" {
  count              = var.enable_ml_inference_alb ? 1 : 0
  name               = "${var.prefix}-ml-inference-alb-${random_id.env_display_id.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.card_tx_alb_sg[0].id]
  subnets            = local.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-ml-inference-alb"
  }
}

# Target Group for ECS tasks
resource "aws_lb_target_group" "card_tx_ml_inference_tg" {
  count                = var.enable_ml_inference_alb ? 1 : 0
  name                 = "${var.prefix}-ml-inference-tg-${random_id.env_display_id.hex}"
  port                 = 8080
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.existing.id
  target_type           = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  tags = {
    Name = "${var.prefix}-ml-inference-tg"
  }
}

# ALB Listener (HTTP) - Redirects to HTTPS if certificate is provided
resource "aws_lb_listener" "card_tx_ml_inference_listener_http" {
  count             = var.enable_ml_inference_alb ? 1 : 0
  load_balancer_arn = aws_lb.card_tx_ml_inference_alb[0].arn
  port              = "80"
  protocol          = "HTTP"

  # Conditional action: redirect to HTTPS if certificate is provided, otherwise forward
  default_action {
    type = local.http_redirect_to_https ? "redirect" : "forward"
    
    dynamic "redirect" {
      for_each = local.http_redirect_to_https ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    dynamic "forward" {
      for_each = local.http_redirect_to_https ? [] : [1]
      content {
        target_group {
          arn = aws_lb_target_group.card_tx_ml_inference_tg[0].arn
        }
      }
    }
  }
}

# ALB Listener (HTTPS) - only created if certificate ARN is provided
resource "aws_lb_listener" "card_tx_ml_inference_listener_https" {
  count             = var.enable_ml_inference_alb && var.ml_inference_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.card_tx_ml_inference_alb[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.ml_inference_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.card_tx_ml_inference_tg[0].arn
  }
}

# Update ECS security group to allow traffic from ALB
resource "aws_security_group_rule" "ecs_allow_alb" {
  count                    = var.enable_ml_inference_alb ? 1 : 0
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.card_tx_alb_sg[0].id
  security_group_id        = aws_security_group.card_tx_ecs_sg.id
  description              = "Allow traffic from ALB"
}

# -----------------------------------------------------------------------------
# ECS Service
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "card_tx_ml_inference_service" {
  name            = "${var.prefix}-ml-inference-service"
  cluster         = aws_ecs_cluster.card_tx_ecs_cluster.id
  task_definition = aws_ecs_task_definition.card_tx_ml_inference_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = local.subnet_ids
    security_groups  = [aws_security_group.card_tx_ecs_sg.id]
    assign_public_ip = !var.enable_ml_inference_alb # Only assign public IP if ALB is not enabled
  }

  # Attach to ALB target group if ALB is enabled
  dynamic "load_balancer" {
    for_each = var.enable_ml_inference_alb ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.card_tx_ml_inference_tg[0].arn
      container_name   = "ml-inference"
      container_port   = 8080
    }
  }

  tags = {
    Name = "${var.prefix}-ml-inference-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}
