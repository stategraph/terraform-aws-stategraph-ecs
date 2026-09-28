variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "production"
}

# VPC
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Domain
variable "domain_name" {
  description = "Public host name of Stategraph, for example stategraph.example.com. Null for an HTTP-only trial on the ALB DNS name"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS. Requires domain_name"
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route 53 hosted zone ID. When set, the example creates the alias record for domain_name"
  type        = string
  default     = null
}

# Stategraph
variable "stategraph_image" {
  description = "Stategraph server image"
  type        = string
  default     = "ghcr.io/stategraph/stategraph-server:3.1.0"
}

variable "license_key" {
  description = "Stategraph Enterprise license key. Null: enter it on the setup screen"
  type        = string
  default     = null
  sensitive   = true
}

variable "cost_enabled" {
  description = "Enable cost estimation"
  type        = bool
  default     = false
}

variable "security_scanning_enabled" {
  description = "Enable security scanning"
  type        = bool
  default     = false
}

# ECS
variable "ecs_task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "Fargate task memory in MB"
  type        = number
  default     = 2048
}

variable "cpu_architecture" {
  description = "CPU architecture of the tasks: X86_64 or ARM64"
  type        = string
  default     = "X86_64"
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

# Database
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

variable "database_deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "database_skip_final_snapshot" {
  description = "Skip the final RDS snapshot on destroy. Trials only"
  type        = bool
  default     = false
}

# OAuth
variable "oauth_enabled" {
  description = "Enable Google or OIDC sign-in"
  type        = bool
  default     = false
}

variable "oauth_provider" {
  description = "OAuth provider: google or oidc"
  type        = string
  default     = ""
}

variable "oauth_client_id" {
  description = "OAuth client ID"
  type        = string
  default     = ""
}

variable "oauth_client_secret" {
  description = "OAuth client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_issuer_url" {
  description = "OIDC issuer URL, for the oidc provider"
  type        = string
  default     = ""
}

variable "oauth_email_domain" {
  description = "Email domain that can sign in. Null: any identity the provider authenticates"
  type        = string
  default     = null
}

# Operations
variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = true
}

variable "secrets_recovery_window_in_days" {
  description = "Days Secrets Manager keeps a deleted secret: 0, or 7 to 30"
  type        = number
  default     = 7
}
