# Network
variable "vpc_id" {
  description = "VPC ID where Stategraph is deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the ECS tasks and RDS"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Subnet IDs for the Application Load Balancer. Public subnets for an internet-facing ALB, private subnets when alb_internal is true"
  type        = list(string)
}

variable "domain_name" {
  description = "Public host name of Stategraph, for example stategraph.example.com. Point its DNS record at the ALB. When null, the ALB DNS name is used and the deployment is HTTP only"
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB. Requires domain_name. When null, the ALB serves HTTP only"
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment name, used in every resource name. Lowercase letters, digits, and hyphens, at most 21 characters"
  type        = string
  default     = "production"

  validation {
    condition     = can(regex("^[a-z0-9-]{1,21}$", var.environment))
    error_message = "environment must match ^[a-z0-9-]{1,21}$."
  }
}

# Stategraph
variable "stategraph_image" {
  description = "Stategraph server image. Pin a release tag in production"
  type        = string
  default     = "ghcr.io/stategraph/stategraph-server:3.1.0"
}

variable "license_key" {
  description = "Stategraph Enterprise license key, stored in Secrets Manager and passed as STATEGRAPH_LICENSE_KEY. When null, the setup screen asks for the key"
  type        = string
  default     = null
  sensitive   = true
}

variable "oauth_enabled" {
  description = "Enable Google or OIDC single sign-on. Local email and password sign-in is on when this is false"
  type        = bool
  default     = false
}

variable "oauth_provider" {
  description = "Sign-in provider when oauth_enabled is true: google or oidc"
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "google", "oidc"], var.oauth_provider)
    error_message = "oauth_provider must be google or oidc."
  }
}

variable "oauth_client_id" {
  description = "OAuth client ID"
  type        = string
  default     = ""
}

variable "oauth_client_secret" {
  description = "OAuth client secret, stored in Secrets Manager"
  type        = string
  default     = ""
  sensitive   = true
}

variable "oauth_issuer_url" {
  description = "OIDC issuer URL, required when oauth_provider is oidc. The provider must serve {issuer}/.well-known/openid-configuration"
  type        = string
  default     = ""
}

variable "oauth_email_domain" {
  description = "Email domain that can sign in through OAuth. When null, the server default applies and any identity the provider authenticates can sign in"
  type        = string
  default     = null
}

variable "oauth_display_name" {
  description = "Provider name on the sign-in button. When null, the server default applies"
  type        = string
  default     = null
}

variable "oauth_cookie_secret" {
  description = "Secret that signs the session and CSRF cookies on every task: 16, 24, or 32 characters. When null, the module generates one and stores it in Secrets Manager"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.oauth_cookie_secret == null || contains([16, 24, 32], length(coalesce(var.oauth_cookie_secret, "")))
    error_message = "oauth_cookie_secret must have 16, 24, or 32 characters."
  }
}

variable "cost_enabled" {
  description = "Enable cost estimation. The price book is loaded into a cloud_pricing database on the same PostgreSQL server"
  type        = bool
  default     = false
}

variable "security_scanning_enabled" {
  description = "Enable security scanning of states with checkov"
  type        = bool
  default     = false
}

variable "extra_environment" {
  description = "Additional environment variables for the server container, for example Orchestration settings"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "extra_secrets" {
  description = "Additional secrets for the server container. Each value_from is a Secrets Manager secret ARN, with an optional :json-key:: suffix. The task execution role gets read access to each secret"
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []

  validation {
    condition = alltrue([
      for s in var.extra_secrets :
      length(split(":", s.value_from)) >= 7 && split(":", s.value_from)[2] == "secretsmanager"
    ])
    error_message = "Each extra_secrets value_from must be a Secrets Manager secret ARN."
  }
}

# Database
variable "create_database" {
  description = "Create an RDS PostgreSQL instance. When false, set the external_database_* variables"
  type        = bool
  default     = true
}

variable "database_engine_version" {
  description = "PostgreSQL engine version of the RDS instance. A major version such as 17 lets RDS pick the current minor version"
  type        = string
  default     = "17"
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
  description = "Maximum allocated storage for RDS storage autoscaling in GB"
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

variable "database_deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "database_skip_final_snapshot" {
  description = "Skip the final snapshot when the RDS instance is destroyed. Use for trials only"
  type        = bool
  default     = false
}

variable "database_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "stategraph"
}

variable "database_username" {
  description = "Master username of the RDS instance"
  type        = string
  default     = "stategraph"
}

# External database, used when create_database is false
variable "external_database_host" {
  description = "External PostgreSQL host"
  type        = string
  default     = ""
}

variable "external_database_port" {
  description = "External PostgreSQL port"
  type        = number
  default     = 5432
}

variable "external_database_name" {
  description = "External PostgreSQL database name. The database must exist before the first start"
  type        = string
  default     = ""
}

variable "external_database_username" {
  description = "External PostgreSQL username"
  type        = string
  default     = ""
  sensitive   = true
}

variable "external_database_password" {
  description = "External PostgreSQL password"
  type        = string
  default     = ""
  sensitive   = true
}

# ECS
variable "ecs_task_cpu" {
  description = "Fargate task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 1024
}

variable "ecs_task_memory" {
  description = "Fargate task memory in MB (512, 1024, 2048, 4096, 8192, 16384, 30720)"
  type        = number
  default     = 2048
}

variable "cpu_architecture" {
  description = "CPU architecture of the Fargate tasks: X86_64 or ARM64. The Stategraph image ships both"
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
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
  description = "Enable ECS autoscaling on CPU and memory"
  type        = bool
  default     = true
}

variable "autoscaling_cpu_threshold" {
  description = "CPU percentage target for autoscaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_threshold" {
  description = "Memory percentage target for autoscaling"
  type        = number
  default     = 80
}

variable "ecs_task_role_policy_arns" {
  description = "IAM policy ARNs to attach to the task role, for example ReadOnlyAccess for gap analysis of the AWS account"
  type        = list(string)
  default     = []
}

variable "container_stop_timeout" {
  description = "Seconds ECS waits for the container to stop before it kills it. Stategraph finishes the requests in progress within 60 seconds"
  type        = number
  default     = 60

  validation {
    condition     = var.container_stop_timeout >= 2 && var.container_stop_timeout <= 120
    error_message = "container_stop_timeout must be between 2 and 120 seconds on Fargate."
  }
}

# Health checks
variable "health_check_path" {
  description = "ALB target group health check path. /health/ready answers 200 only when the server has migrated and serves requests"
  type        = string
  default     = "/health/ready"
}

variable "container_health_check_path" {
  description = "ECS container health check path. /health/live answers 200 as soon as the web server is up, also during migrations"
  type        = string
  default     = "/health/live"
}

variable "container_health_check_start_period" {
  description = "Seconds before ECS counts container health check failures. Covers the migrations at the first start"
  type        = number
  default     = 120
}

variable "health_check_grace_period_seconds" {
  description = "Seconds the ECS service ignores ALB health check failures after a task starts. Must cover the migration time at the first start"
  type        = number
  default     = 300
}

variable "health_check_interval" {
  description = "Health check interval in seconds, for the ALB and the container"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds, for the ALB and the container"
  type        = number
  default     = 5
}

variable "health_check_healthy_threshold" {
  description = "Consecutive ALB health check successes before a target is healthy"
  type        = number
  default     = 2
}

variable "health_check_unhealthy_threshold" {
  description = "Consecutive health check failures before a target is unhealthy, for the ALB and the container"
  type        = number
  default     = 5
}

# Load balancer
variable "alb_internal" {
  description = "Create an internal ALB. Pass private subnets in public_subnet_ids when true"
  type        = bool
  default     = false
}

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on ports 80 and 443"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.alb_ingress_cidrs) > 0 && alltrue([for c in var.alb_ingress_cidrs : can(cidrhost(c, 0))])
    error_message = "alb_ingress_cidrs must hold at least one valid IPv4 CIDR block."
  }
}

variable "alb_idle_timeout" {
  description = "ALB idle timeout in seconds. The server closes idle API requests after 120 seconds"
  type        = number
  default     = 120
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection on the ALB"
  type        = bool
  default     = true
}

variable "alb_access_logs_enabled" {
  description = "Enable ALB access logs"
  type        = bool
  default     = false
}

variable "alb_access_logs_bucket" {
  description = "S3 bucket for ALB access logs, required when alb_access_logs_enabled is true"
  type        = string
  default     = ""
}

variable "alb_access_logs_prefix" {
  description = "Prefix for ALB access logs in S3"
  type        = string
  default     = "alb-logs"
}

# Secrets, logs, tags
variable "secrets_recovery_window_in_days" {
  description = "Days Secrets Manager keeps a deleted secret before it removes it: 0 for at once, or 7 to 30. Use 0 for trials that are created and destroyed often"
  type        = number
  default     = 7

  validation {
    condition     = var.secrets_recovery_window_in_days == 0 || (var.secrets_recovery_window_in_days >= 7 && var.secrets_recovery_window_in_days <= 30)
    error_message = "secrets_recovery_window_in_days must be 0 or between 7 and 30."
  }
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
