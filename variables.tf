variable "vpc_id" {
  description = "VPC ID where Stategraph will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks and RDS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for Application Load Balancer"
  type        = list(string)
}

variable "domain_name" {
  description = "Domain name for Stategraph (e.g., stategraph.example.com)"
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "production"
}

# Database configuration
variable "create_database" {
  description = "Whether to create an RDS PostgreSQL database"
  type        = bool
  default     = true
}

variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.medium"
}

variable "database_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 100
}

variable "database_max_allocated_storage" {
  description = "Maximum allocated storage for RDS autoscaling in GB"
  type        = number
  default     = 500
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

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "stategraph"
}

variable "database_username" {
  description = "Master username for the database"
  type        = string
  default     = "stategraph"
}

# External database configuration (used when create_database = false)
variable "external_database_host" {
  description = "External PostgreSQL database host"
  type        = string
  default     = ""
}

variable "external_database_port" {
  description = "External PostgreSQL database port"
  type        = number
  default     = 5432
}

variable "external_database_name" {
  description = "External PostgreSQL database name"
  type        = string
  default     = ""
}

variable "external_database_username" {
  description = "External PostgreSQL database username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_database_password" {
  description = "External PostgreSQL database password"
  type        = string
  default     = ""
  sensitive   = true
}

# ECS configuration
variable "ecs_task_cpu" {
  description = "ECS task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "ECS task memory in MB (512, 1024, 2048, 4096, 8192, 16384, 30720)"
  type        = number
  default     = 2048
}

variable "ecs_desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 2
}

variable "ecs_max_count" {
  description = "Maximum number of ECS tasks for autoscaling"
  type        = number
  default     = 4
}

variable "ecs_min_count" {
  description = "Minimum number of ECS tasks for autoscaling"
  type        = number
  default     = 1
}

variable "enable_autoscaling" {
  description = "Enable ECS autoscaling based on CPU and memory"
  type        = bool
  default     = true
}

variable "autoscaling_cpu_threshold" {
  description = "CPU percentage threshold for autoscaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_threshold" {
  description = "Memory percentage threshold for autoscaling"
  type        = number
  default     = 80
}

variable "stategraph_image" {
  description = "Stategraph Docker image"
  type        = string
  default     = "ghcr.io/stategraph/stategraph-server:latest"
}

variable "container_port" {
  description = "Port the Stategraph container listens on"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "Health check path for the application"
  type        = string
  default     = "/api/v1/health"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive health checks successes required"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive health check failures required"
  type        = number
  default     = 3
}

# ALB configuration
variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds"
  type        = number
  default     = 60
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = true
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs (required if alb_access_logs_enabled is true)"
  type        = string
  default     = ""
}

variable "alb_access_logs_prefix" {
  description = "Prefix for ALB access logs in S3"
  type        = string
  default     = "alb-logs"
}

# OAuth configuration
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
}

variable "oauth_client_secret" {
  description = "OAuth client secret"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_issuer_url" {
  description = "OAuth issuer URL (required for OIDC provider)"
  type        = string
  default     = ""
}

# CloudWatch Logs configuration
variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
