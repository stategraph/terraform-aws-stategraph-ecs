# Task execution role: pulls the image, reads the secrets, writes the logs
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

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

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
        Resource = concat(
          [
            aws_secretsmanager_secret.database.arn,
            aws_secretsmanager_secret.stategraph.arn,
          ],
          local.extra_secret_arns,
        )
      }
    ]
  })
}

# Task role: the identity of the running server
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

resource "aws_iam_role_policy_attachment" "ecs_task_extra" {
  for_each = toset(var.ecs_task_role_policy_arns)

  role       = aws_iam_role.ecs_task.name
  policy_arn = each.value
}
