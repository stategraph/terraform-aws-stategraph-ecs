data "aws_region" "current" {}

# Generate random password for database
resource "random_password" "database" {
  length  = 32
  special = true
}

# CloudWatch Log Group for ECS container logs
resource "aws_cloudwatch_log_group" "stategraph" {
  name              = "/ecs/stategraph-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )
}

# Secrets Manager - Database credentials
resource "aws_secretsmanager_secret" "database" {
  name = "stategraph-database-${var.environment}"

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-database-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "database" {
  secret_id = aws_secretsmanager_secret.database.id
  secret_string = jsonencode({
    username = var.create_database ? var.database_username : var.external_database_username
    password = var.create_database ? random_password.database.result : var.external_database_password
  })
}

# Secrets Manager - OAuth credentials (if enabled)
resource "aws_secretsmanager_secret" "oauth" {
  count = var.oauth_enabled ? 1 : 0

  name = "stategraph-oauth-${var.environment}"

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-oauth-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "oauth" {
  count = var.oauth_enabled ? 1 : 0

  secret_id = aws_secretsmanager_secret.oauth[0].id
  secret_string = jsonencode({
    client_id     = var.oauth_client_id
    client_secret = var.oauth_client_secret
  })
}

# RDS Subnet Group (only if using managed RDS)
resource "aws_db_subnet_group" "stategraph" {
  count = var.create_database ? 1 : 0

  name       = "stategraph-${var.environment}"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )
}

# RDS PostgreSQL Instance (only if using managed RDS)
resource "aws_db_instance" "stategraph" {
  count = var.create_database ? 1 : 0

  identifier     = "stategraph-${var.environment}"
  engine         = "postgres"
  engine_version = "16.3"
  instance_class = var.database_instance_class

  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = var.database_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.database_name
  username = var.database_username
  password = random_password.database.result

  multi_az               = var.database_multi_az
  db_subnet_group_name   = aws_db_subnet_group.stategraph[0].name
  vpc_security_group_ids = [aws_security_group.rds[0].id]

  backup_retention_period = var.database_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = false
  final_snapshot_identifier = "stategraph-${var.environment}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# Application Load Balancer
resource "aws_lb" "stategraph" {
  name               = "stategraph-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.alb_idle_timeout

  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = var.alb_access_logs_prefix
      enabled = true
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )
}

# ALB Target Group
resource "aws_lb_target_group" "stategraph" {
  name        = "stategraph-${var.environment}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = var.health_check_interval
    timeout             = var.health_check_timeout
    healthy_threshold   = var.health_check_healthy_threshold
    unhealthy_threshold = var.health_check_unhealthy_threshold
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )
}

# ALB Listener - HTTPS
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.stategraph.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.stategraph.arn
  }

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-https-${var.environment}"
      Environment = var.environment
    }
  )
}

# ALB Listener - HTTP (redirect to HTTPS)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.stategraph.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-http-${var.environment}"
      Environment = var.environment
    }
  )
}

# ECS Cluster
resource "aws_ecs_cluster" "stategraph" {
  name = "stategraph-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )
}

# ECS Task Definition
resource "aws_ecs_task_definition" "stategraph" {
  family                   = "stategraph-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name      = "stategraph"
    image     = var.stategraph_image
    essential = true

    portMappings = [{
      containerPort = var.container_port
      protocol      = "tcp"
    }]

    environment = concat([
      {
        name  = "STATEGRAPH_UI_BASE"
        value = "https://${var.domain_name}"
      },
      {
        name  = "DB_HOST"
        value = var.create_database ? aws_db_instance.stategraph[0].address : var.external_database_host
      },
      {
        name  = "DB_PORT"
        value = tostring(var.create_database ? 5432 : var.external_database_port)
      },
      {
        name  = "DB_NAME"
        value = var.create_database ? aws_db_instance.stategraph[0].db_name : var.external_database_name
      }
      ], var.oauth_enabled ? [
      {
        name  = "OAUTH_PROVIDER"
        value = var.oauth_provider
      },
      {
        name  = "OAUTH_CLIENT_ID"
        value = var.oauth_client_id
      },
      {
        name  = "OAUTH_ISSUER_URL"
        value = var.oauth_issuer_url
      }
    ] : [])

    secrets = concat([
      {
        name      = "DB_USER"
        valueFrom = "${aws_secretsmanager_secret.database.arn}:username::"
      },
      {
        name      = "DB_PASS"
        valueFrom = "${aws_secretsmanager_secret.database.arn}:password::"
      }
      ], var.oauth_enabled ? [
      {
        name      = "OAUTH_CLIENT_SECRET"
        valueFrom = "${aws_secretsmanager_secret.oauth[0].arn}:client_secret::"
      }
    ] : [])

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.stategraph.name
        "awslogs-region"        = data.aws_region.current.id
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}${var.health_check_path} || exit 1"]
      interval    = var.health_check_interval
      timeout     = var.health_check_timeout
      retries     = var.health_check_unhealthy_threshold
      startPeriod = 60
    }
  }])

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )
}

# ECS Service
resource "aws_ecs_service" "stategraph" {
  name            = "stategraph-${var.environment}"
  cluster         = aws_ecs_cluster.stategraph.id
  task_definition = aws_ecs_task_definition.stategraph.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stategraph.arn
    container_name   = "stategraph"
    container_port   = var.container_port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # Wait for ALB to be ready before deploying tasks
  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http
  ]

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-${var.environment}"
      Environment = var.environment
    }
  )

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Auto Scaling Target (if autoscaling enabled)
resource "aws_appautoscaling_target" "ecs" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.stategraph.name}/${aws_ecs_service.stategraph.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Auto Scaling Policy - CPU
resource "aws_appautoscaling_policy" "ecs_cpu" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "stategraph-cpu-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_threshold
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# Auto Scaling Policy - Memory
resource "aws_appautoscaling_policy" "ecs_memory" {
  count = var.enable_autoscaling ? 1 : 0

  name               = "stategraph-memory-${var.environment}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs[0].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs[0].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs[0].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_memory_threshold
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
