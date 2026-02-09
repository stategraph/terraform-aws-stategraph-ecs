output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.stategraph.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.stategraph.name
}

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.stategraph.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.stategraph.name
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.stategraph.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer (for Route53 alias records)"
  value       = aws_lb.stategraph.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.stategraph.arn
}

output "target_group_arn" {
  description = "ARN of the ALB target group"
  value       = aws_lb_target_group.stategraph.arn
}

output "database_endpoint" {
  description = "Endpoint of the RDS database (empty if using external database)"
  value       = var.create_database ? aws_db_instance.stategraph[0].endpoint : ""
}

output "database_name" {
  description = "Name of the database"
  value       = var.create_database ? aws_db_instance.stategraph[0].db_name : var.external_database_name
}

output "database_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.database.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch Log Group for ECS container logs"
  value       = aws_cloudwatch_log_group.stategraph.name
}

output "security_group_alb_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "security_group_ecs_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs.id
}

output "security_group_rds_id" {
  description = "ID of the RDS security group (empty if using external database)"
  value       = var.create_database ? aws_security_group.rds[0].id : ""
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}
