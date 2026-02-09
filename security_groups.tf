# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name        = "stategraph-alb-${var.environment}"
  description = "Security group for Stategraph Application Load Balancer"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-alb-${var.environment}"
      Environment = var.environment
    }
  )
}

# Allow HTTP traffic from internet
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from internet"

  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Allow HTTPS traffic from internet
resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow HTTPS from internet"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Allow all outbound traffic from ALB
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Allow all outbound traffic"

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs" {
  name        = "stategraph-ecs-${var.environment}"
  description = "Security group for Stategraph ECS tasks"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-ecs-${var.environment}"
      Environment = var.environment
    }
  )
}

# Allow traffic from ALB to ECS tasks
resource "aws_vpc_security_group_ingress_rule" "ecs_from_alb" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow traffic from ALB"

  from_port                    = var.container_port
  to_port                      = var.container_port
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

# Allow HTTPS outbound for external API calls
resource "aws_vpc_security_group_egress_rule" "ecs_https" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow HTTPS outbound for external APIs"

  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Allow DNS outbound
resource "aws_vpc_security_group_egress_rule" "ecs_dns" {
  security_group_id = aws_security_group.ecs.id
  description       = "Allow DNS queries"

  from_port   = 53
  to_port     = 53
  ip_protocol = "udp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Allow PostgreSQL outbound to RDS (if using managed RDS)
resource "aws_vpc_security_group_egress_rule" "ecs_postgres" {
  count = var.create_database ? 1 : 0

  security_group_id = aws_security_group.ecs.id
  description       = "Allow PostgreSQL to RDS"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.rds[0].id
}

# Allow PostgreSQL outbound to external database (if using external DB)
resource "aws_vpc_security_group_egress_rule" "ecs_external_postgres" {
  count = var.create_database ? 0 : 1

  security_group_id = aws_security_group.ecs.id
  description       = "Allow PostgreSQL to external database"

  from_port   = var.external_database_port
  to_port     = var.external_database_port
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

# Security Group for RDS (only created if using managed RDS)
resource "aws_security_group" "rds" {
  count = var.create_database ? 1 : 0

  name        = "stategraph-rds-${var.environment}"
  description = "Security group for Stategraph RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    {
      Name        = "stategraph-rds-${var.environment}"
      Environment = var.environment
    }
  )
}

# Allow PostgreSQL traffic from ECS tasks only
resource "aws_vpc_security_group_ingress_rule" "rds_from_ecs" {
  count = var.create_database ? 1 : 0

  security_group_id = aws_security_group.rds[0].id
  description       = "Allow PostgreSQL from ECS tasks"

  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ecs.id
}

# No outbound rules needed for RDS (it doesn't initiate connections)
