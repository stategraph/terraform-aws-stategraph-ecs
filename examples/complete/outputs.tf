output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnets
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer - point your domain here"
  value       = module.stategraph.alb_dns_name
}

output "alb_zone_id" {
  description = "Route53 zone ID of the ALB (for alias records)"
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
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = module.stategraph.database_secret_arn
}

output "cloudwatch_log_group" {
  description = "CloudWatch Log Group name for container logs"
  value       = module.stategraph.cloudwatch_log_group_name
}

output "next_steps" {
  description = "Next steps after deployment"
  value       = <<-EOT
    Deployment complete! Next steps:

    1. Create DNS record:
       - Point ${var.domain_name} to: ${module.stategraph.alb_dns_name}
       - Or use Route53 alias to zone: ${module.stategraph.alb_zone_id}

    2. Wait for DNS propagation (5-10 minutes)

    3. Access Stategraph at: https://${var.domain_name}

    4. View logs:
       aws logs tail ${module.stategraph.cloudwatch_log_group_name} --follow

    5. Monitor service:
       aws ecs describe-services --cluster ${module.stategraph.ecs_cluster_name} --services ${module.stategraph.ecs_service_name}
  EOT
}
