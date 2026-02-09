# ECS Task Execution Role - Used by ECS to pull images and write logs
resource "aws_iam_role" "ecs_execution" {
  name = "stategraph-ecs-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-ecs-execution-${var.environment}"
      Environment = var.environment
    }
  )
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Custom policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_execution_secrets" {
  name = "stategraph-ecs-execution-secrets-${var.environment}"
  role = aws_iam_role.ecs_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = compact([
          aws_secretsmanager_secret.database.arn,
          var.oauth_enabled ? aws_secretsmanager_secret.oauth[0].arn : null
        ])
      }
    ]
  })
}

# ECS Task Role - Used by the running container (application permissions)
resource "aws_iam_role" "ecs_task" {
  name = "stategraph-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-ecs-task-${var.environment}"
      Environment = var.environment
    }
  )
}

# Add any application-specific permissions here
# Example: S3 access for state storage
resource "aws_iam_role_policy" "ecs_task_app" {
  name = "stategraph-ecs-task-app-${var.environment}"
  role = aws_iam_role.ecs_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.stategraph.arn}:*"
      }
    ]
  })
}
