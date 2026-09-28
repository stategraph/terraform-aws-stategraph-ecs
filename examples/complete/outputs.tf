output "stategraph_url" {
  description = "URL of the Stategraph console"
  value       = module.stategraph.stategraph_url
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnets
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer. Point your domain here"
  value       = module.stategraph.alb_dns_name
}

output "alb_zone_id" {
  description = "Route 53 zone ID of the ALB, for alias records"
  value       = module.stategraph.alb_zone_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.stategraph.ecs_cluster_name
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = module.stategraph.ecs_service_name
}

output "database_endpoint" {
  description = "Endpoint of the RDS database"
  value       = module.stategraph.database_endpoint
  sensitive   = true
}

output "database_secret_arn" {
  description = "ARN of the Secrets Manager secret with the database credentials"
  value       = module.stategraph.database_secret_arn
}

output "stategraph_secret_arn" {
  description = "ARN of the Secrets Manager secret with the server secrets"
  value       = module.stategraph.stategraph_secret_arn
}

output "cloudwatch_log_group_name" {
  description = "CloudWatch Log Group of the container logs"
  value       = module.stategraph.cloudwatch_log_group_name
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    Deployment complete. Next steps:

    1. DNS: point ${coalesce(var.domain_name, "your domain")} at ${module.stategraph.alb_dns_name}
       or create a Route 53 alias to zone ${module.stategraph.alb_zone_id}.
       Not needed for an HTTP-only trial on the ALB DNS name.

    2. Wait for the first start. Migrations run before the server accepts requests:
       curl -f ${module.stategraph.stategraph_url}/health/ready

    3. Open ${module.stategraph.stategraph_url} and create the first admin account.

    4. Logs:
       aws logs tail ${module.stategraph.cloudwatch_log_group_name} --follow

    5. Service status:
       aws ecs describe-services --cluster ${module.stategraph.ecs_cluster_name} --services ${module.stategraph.ecs_service_name}
  EOT
}
