terraform {
  required_version = ">= 1.3"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

# VPC with public subnets for the ALB and private subnets, behind NAT, for
# the tasks and RDS. Skip this module and pass your own subnets if you have a VPC.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "stategraph-${var.environment}"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = var.environment != "production"

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.tags
}

module "stategraph" {
  source = "../../"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnets
  public_subnet_ids  = module.vpc.public_subnets

  # Both null: HTTP only, on the ALB DNS name.
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn

  environment = var.environment

  stategraph_image = var.stategraph_image
  license_key      = var.license_key

  ecs_task_cpu       = var.ecs_task_cpu
  ecs_task_memory    = var.ecs_task_memory
  cpu_architecture   = var.cpu_architecture
  ecs_desired_count  = var.ecs_desired_count
  enable_autoscaling = var.enable_autoscaling
  ecs_max_count      = var.ecs_max_count
  ecs_min_count      = var.ecs_min_count

  database_instance_class          = var.database_instance_class
  database_multi_az                = var.database_multi_az
  database_backup_retention_period = var.database_backup_retention_period
  database_allocated_storage       = var.database_allocated_storage
  database_deletion_protection     = var.database_deletion_protection
  database_skip_final_snapshot     = var.database_skip_final_snapshot

  oauth_enabled       = var.oauth_enabled
  oauth_provider      = var.oauth_provider
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
  oauth_issuer_url    = var.oauth_issuer_url
  oauth_email_domain  = var.oauth_email_domain

  cost_enabled              = var.cost_enabled
  security_scanning_enabled = var.security_scanning_enabled

  log_retention_days              = var.log_retention_days
  enable_deletion_protection      = var.enable_deletion_protection
  secrets_recovery_window_in_days = var.secrets_recovery_window_in_days

  tags = local.tags
}

# Route 53 alias record, when route53_zone_id is set.
resource "aws_route53_record" "stategraph" {
  count = var.route53_zone_id != null ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = module.stategraph.alb_dns_name
    zone_id                = module.stategraph.alb_zone_id
    evaluate_target_health = true
  }
}

locals {
  tags = {
    Environment = var.environment
    Project     = "Stategraph"
    ManagedBy   = "Terraform"
  }
}
