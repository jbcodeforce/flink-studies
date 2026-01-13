# -----------------------------------------------------------------------------
# ML Inference Infrastructure (ECS/Fargate)
# Card Transaction Processing Demo
# -----------------------------------------------------------------------------

locals {
  cpu_architecture = var.local_architecture == "arm64" || var.local_architecture == "aarch64" ? "ARM64" : "X86_64"
}

# -----------------------------------------------------------------------------
# Security Group for ECS
# -----------------------------------------------------------------------------
resource "aws_security_group" "card_tx_ecs_sg" {
  name        = "${var.prefix}-ecs-sg-${random_id.env_display_id.hex}"
  description = "Security group for Card TX ML Inference ECS tasks"
  vpc_id      = data.aws_vpc.existing.id

  # HTTP ingress for Flink to call ML inference
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP API for ML inference"
  }

  # HTTPS ingress
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS API for ML inference"
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
    assign_public_ip = true
  }

  tags = {
    Name = "${var.prefix}-ml-inference-service"
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}
