data "aws_region" "current" {}

locals {
  name = "stategraph-${var.environment}"

  # nginx inside the image listens on 8080.
  container_port = 8080

  scheme  = var.certificate_arn != null ? "https" : "http"
  host    = coalesce(var.domain_name, aws_lb.stategraph.dns_name)
  ui_base = "${local.scheme}://${local.host}"

  db_host = var.create_database ? aws_db_instance.stategraph[0].address : var.external_database_host
  db_port = var.create_database ? aws_db_instance.stategraph[0].port : var.external_database_port
  db_name = var.create_database ? aws_db_instance.stategraph[0].db_name : var.external_database_name

  license_key_set = nonsensitive(var.license_key != null)

  tags = merge(
    var.tags,
    {
      Name        = local.name
      Environment = var.environment
    }
  )

  container_environment = concat(
    [
      { name = "STATEGRAPH_UI_BASE", value = local.ui_base },
      { name = "STATEGRAPH_OAUTH_REDIRECT_BASE", value = local.ui_base },
      { name = "DB_HOST", value = local.db_host },
      { name = "DB_PORT", value = tostring(local.db_port) },
      { name = "DB_NAME", value = local.db_name },
    ],
    var.oauth_enabled ? [
      { name = "STATEGRAPH_OAUTH_TYPE", value = var.oauth_provider },
      { name = "STATEGRAPH_OAUTH_CLIENT_ID", value = var.oauth_client_id },
    ] : [],
    var.oauth_enabled && var.oauth_provider == "oidc" ? [
      { name = "STATEGRAPH_OAUTH_OIDC_ISSUER_URL", value = var.oauth_issuer_url },
    ] : [],
    var.oauth_enabled && var.oauth_email_domain != null ? [
      { name = "STATEGRAPH_OAUTH_EMAIL_DOMAIN", value = var.oauth_email_domain },
    ] : [],
    var.oauth_enabled && var.oauth_display_name != null ? [
      { name = "STATEGRAPH_OAUTH_DISPLAY_NAME", value = var.oauth_display_name },
    ] : [],
    var.cost_enabled ? [
      { name = "STATEGRAPH_COST_ENABLED", value = "true" },
      { name = "PRICING_DB_HOST", value = local.db_host },
      { name = "PRICING_DB_PORT", value = tostring(local.db_port) },
      { name = "PRICING_DB_NAME", value = "cloud_pricing" },
      { name = "PRICING_DB_SSLMODE", value = "require" },
    ] : [],
    var.security_scanning_enabled ? [
      { name = "STATEGRAPH_SECURITY", value = "1" },
    ] : [],
    var.extra_environment,
  )

  container_secrets = concat(
    [
      { name = "DB_USER", valueFrom = "${aws_secretsmanager_secret.database.arn}:username::" },
      { name = "DB_PASS", valueFrom = "${aws_secretsmanager_secret.database.arn}:password::" },
      { name = "STATEGRAPH_OAUTH_COOKIE_SECRET", valueFrom = "${aws_secretsmanager_secret.stategraph.arn}:cookie_secret::" },
    ],
    local.license_key_set ? [
      { name = "STATEGRAPH_LICENSE_KEY", valueFrom = "${aws_secretsmanager_secret.stategraph.arn}:license_key::" },
    ] : [],
    var.oauth_enabled ? [
      { name = "STATEGRAPH_OAUTH_CLIENT_SECRET", valueFrom = "${aws_secretsmanager_secret.stategraph.arn}:oauth_client_secret::" },
    ] : [],
    var.cost_enabled ? [
      { name = "PRICING_DB_USER", valueFrom = "${aws_secretsmanager_secret.database.arn}:username::" },
      { name = "PRICING_DB_PASSWORD", valueFrom = "${aws_secretsmanager_secret.database.arn}:password::" },
    ] : [],
    [for s in var.extra_secrets : { name = s.name, valueFrom = s.value_from }],
  )

  # The secret ARN without a :json-key:: suffix, for the execution role policy.
  extra_secret_arns = distinct([
    for s in var.extra_secrets : join(":", slice(split(":", s.value_from), 0, 7))
  ])
}

# RDS rejects /, @, " and space in a master password.
resource "random_password" "database" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "cookie_secret" {
  length  = 32
  special = false
}

resource "aws_cloudwatch_log_group" "stategraph" {
  name              = "/ecs/${local.name}"
  retention_in_days = var.log_retention_days

  tags = local.tags
}

# Database credentials
resource "aws_secretsmanager_secret" "database" {
  name                    = "stategraph-database-${var.environment}"
  recovery_window_in_days = var.secrets_recovery_window_in_days

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

# Server secrets: cookie secret, license key, OAuth client secret
resource "aws_secretsmanager_secret" "stategraph" {
  name                    = "stategraph-server-${var.environment}"
  recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-server-${var.environment}"
      Environment = var.environment
    }
  )
}

resource "aws_secretsmanager_secret_version" "stategraph" {
  secret_id = aws_secretsmanager_secret.stategraph.id
  secret_string = jsonencode(merge(
    { cookie_secret = coalesce(var.oauth_cookie_secret, random_password.cookie_secret.result) },
    local.license_key_set ? { license_key = var.license_key } : {},
    var.oauth_enabled ? { oauth_client_secret = var.oauth_client_secret } : {},
  ))
}

# RDS
resource "aws_db_subnet_group" "stategraph" {
  count = var.create_database ? 1 : 0

  name       = local.name
  subnet_ids = var.private_subnet_ids

  tags = local.tags
}

resource "aws_db_instance" "stategraph" {
  count = var.create_database ? 1 : 0

  identifier                 = local.name
  engine                     = "postgres"
  engine_version             = var.database_engine_version
  auto_minor_version_upgrade = true
  instance_class             = var.database_instance_class

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

  deletion_protection     = var.database_deletion_protection
  copy_tags_to_snapshot   = true
  backup_retention_period = var.database_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = var.database_skip_final_snapshot
  final_snapshot_identifier = var.database_skip_final_snapshot ? null : "${local.name}-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = local.tags

  lifecycle {
    ignore_changes = [
      final_snapshot_identifier
    ]
  }
}

# Application Load Balancer
resource "aws_lb" "stategraph" {
  name               = local.name
  internal           = var.alb_internal
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  idle_timeout               = var.alb_idle_timeout
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.alb_access_logs_enabled ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = var.alb_access_logs_prefix
      enabled = true
    }
  }

  tags = local.tags

  lifecycle {
    precondition {
      condition     = var.certificate_arn == null || var.domain_name != null
      error_message = "certificate_arn requires domain_name: the certificate must match the host name users open."
    }

    precondition {
      condition     = !var.alb_access_logs_enabled || var.alb_access_logs_bucket != ""
      error_message = "alb_access_logs_bucket is required when alb_access_logs_enabled is true."
    }
  }
}

resource "aws_lb_target_group" "stategraph" {
  name        = local.name
  port        = local.container_port
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

  tags = local.tags
}

resource "aws_lb_listener" "https" {
  count = var.certificate_arn != null ? 1 : 0

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

# HTTP: redirect to HTTPS when a certificate is set, forward otherwise.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.stategraph.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = var.certificate_arn != null ? "redirect" : "forward"
    target_group_arn = var.certificate_arn != null ? null : aws_lb_target_group.stategraph.arn

    dynamic "redirect" {
      for_each = var.certificate_arn != null ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
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

# ECS
resource "aws_ecs_cluster" "stategraph" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.tags
}

resource "aws_ecs_task_definition" "stategraph" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = var.cpu_architecture
  }

  # hostPort and the empty collections match what ECS stores, so plans stay quiet.
  container_definitions = jsonencode([{
    name        = "stategraph"
    image       = var.stategraph_image
    essential   = true
    stopTimeout = var.container_stop_timeout

    portMappings = [{
      containerPort = local.container_port
      hostPort      = local.container_port
      protocol      = "tcp"
    }]

    mountPoints    = []
    systemControls = []
    volumesFrom    = []

    environment = local.container_environment
    secrets     = local.container_secrets

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.stategraph.name
        "awslogs-region"        = data.aws_region.current.region
        "awslogs-stream-prefix" = "ecs"
      }
    }

    healthCheck = {
      command     = ["CMD-SHELL", "curl -f http://localhost:${local.container_port}${var.container_health_check_path} || exit 1"]
      interval    = var.health_check_interval
      timeout     = var.health_check_timeout
      retries     = var.health_check_unhealthy_threshold
      startPeriod = var.container_health_check_start_period
    }
  }])

  tags = local.tags

  lifecycle {
    precondition {
      condition     = !var.oauth_enabled || contains(["google", "oidc"], var.oauth_provider)
      error_message = "oauth_provider must be google or oidc when oauth_enabled is true."
    }

    precondition {
      condition     = !var.oauth_enabled || var.oauth_provider != "oidc" || var.oauth_issuer_url != ""
      error_message = "oauth_issuer_url is required when oauth_provider is oidc."
    }

    precondition {
      condition     = var.create_database || (var.external_database_host != "" && var.external_database_name != "")
      error_message = "external_database_host and external_database_name are required when create_database is false."
    }
  }
}

resource "aws_ecs_service" "stategraph" {
  name            = local.name
  cluster         = aws_ecs_cluster.stategraph.id
  task_definition = aws_ecs_task_definition.stategraph.arn
  desired_count   = var.ecs_desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.stategraph.arn
    container_name   = "stategraph"
    container_port   = local.container_port
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [
    aws_lb_listener.https,
    aws_lb_listener.http
  ]

  tags = local.tags

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# Autoscaling
resource "aws_appautoscaling_target" "ecs" {
  count = var.enable_autoscaling ? 1 : 0

  max_capacity       = var.ecs_max_count
  min_capacity       = var.ecs_min_count
  resource_id        = "service/${aws_ecs_cluster.stategraph.name}/${aws_ecs_service.stategraph.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

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
