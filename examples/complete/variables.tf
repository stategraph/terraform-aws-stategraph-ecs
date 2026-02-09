variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Domain Configuration
variable "domain_name" {
  description = "Domain name for Stategraph (e.g., stategraph.example.com)"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

# Optional: Route53 configuration
# variable "route53_zone_id" {
#   description = "Route53 hosted zone ID for DNS record creation"
#   type        = string
#   default     = ""
# }

# ECS Configuration
variable "ecs_task_cpu" {
  description = "ECS task CPU units"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB"
  type        = number
  default     = 2048
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "enable_autoscaling" {
  description = "Enable ECS autoscaling"
  type        = bool
  default     = true
}

variable "ecs_max_count" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 4
}

variable "ecs_min_count" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

variable "stategraph_image" {
  description = "Stategraph Docker image"
  type        = string
  default     = "ghcr.io/stategraph/stategraph-server:latest"
}

# Database Configuration
variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "database_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = true
}

variable "database_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "database_allocated_storage" {
  description = "Initial allocated storage in GB"
  type        = number
  default     = 100
}

# OAuth Configuration
variable "oauth_enabled" {
  description = "Enable OAuth authentication"
  type        = bool
  default     = false
}

variable "oauth_provider" {
  description = "OAuth provider (google, github, oidc)"
  type        = string
  default     = ""
}

variable "oauth_client_id" {
  description = "OAuth client ID"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_client_secret" {
  description = "OAuth client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_issuer_url" {
  description = "OAuth issuer URL (for OIDC provider)"
  type        = string
  default     = ""
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

# Security Configuration
variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true
}
