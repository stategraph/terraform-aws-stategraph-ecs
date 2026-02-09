terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Module - Creates networking infrastructure
# You can skip this if you already have a VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "stategraph-${var.environment}"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = var.environment != "production" # Use single NAT for dev to save costs

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.environment
    Project     = "Stategraph"
    ManagedBy   = "Terraform"
  }
}

# Stategraph ECS Module - Deploys the application
module "stategraph" {
  source = "stategraph/stategraph-ecs/aws"
  # version = "~> 1.0"  # Uncomment to pin to specific version

  # For local development:
  # source = "../../"

  # Network configuration
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  # Domain and certificate
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn

  # Environment
  environment = var.environment

  # ECS configuration
  ecs_task_cpu       = var.ecs_task_cpu
  ecs_task_memory    = var.ecs_task_memory
  ecs_desired_count  = var.ecs_desired_count
  enable_autoscaling = var.enable_autoscaling
  ecs_max_count      = var.ecs_max_count
  ecs_min_count      = var.ecs_min_count
  stategraph_image   = var.stategraph_image

  # Database configuration
  database_instance_class          = var.database_instance_class
  database_multi_az                = var.database_multi_az
  database_backup_retention_period = var.database_backup_retention_period
  database_allocated_storage       = var.database_allocated_storage

  # OAuth configuration (optional)
  oauth_enabled       = var.oauth_enabled
  oauth_provider      = var.oauth_provider
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
  oauth_issuer_url    = var.oauth_issuer_url

  # Monitoring
  log_retention_days = var.log_retention_days

  # Security
  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Environment = var.environment
    Project     = "Stategraph"
    ManagedBy   = "Terraform"
  }
}

# Route53 DNS Record (optional)
# Uncomment if you want to automatically create a DNS record
# resource "aws_route53_record" "stategraph" {
#   zone_id = var.route53_zone_id
#   name    = var.domain_name
#   type    = "A"
#
#   alias {
#     name                   = module.stategraph.alb_dns_name
#     zone_id                = module.stategraph.alb_zone_id
#     evaluate_target_health = true
#   }
# }
