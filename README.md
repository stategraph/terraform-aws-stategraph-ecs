# Stategraph ECS Terraform Module

Deploy Stategraph on AWS ECS Fargate with a complete, production-ready infrastructure stack.

## Features

- **ECS Fargate Deployment**: Serverless container orchestration
- **Application Load Balancer**: HTTPS with automatic HTTP redirect
- **RDS PostgreSQL**: Managed database with Multi-AZ, automated backups
- **Secrets Management**: Credentials stored securely in AWS Secrets Manager
- **Auto Scaling**: CPU and memory-based autoscaling for ECS tasks
- **CloudWatch Monitoring**: Container logs and metrics with Container Insights
- **Security Best Practices**: Least-privilege IAM roles, private subnets, security groups

## Prerequisites

- **VPC**: Existing VPC with private and public subnets
- **ACM Certificate**: Valid SSL certificate for your domain
- **Terraform**: Version 1.0 or higher
- **AWS CLI**: Configured with appropriate credentials

## Quick Start

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.0.0"

  # Network configuration (required)
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # Domain and certificate (required)
  domain_name     = "stategraph.example.com"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

  # Environment (optional)
  environment = "production"

  # Tags (optional)
  tags = {
    Project   = "Stategraph"
    ManagedBy = "Terraform"
  }
}

output "alb_dns_name" {
  description = "Load balancer DNS - create a CNAME record pointing your domain here"
  value       = module.stategraph.alb_dns_name
}

output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.stategraph.database_endpoint
}
```

## Usage

### 1. Create your Terraform configuration

Create a file named `main.tf` with the module configuration above.

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Review the plan

```bash
terraform plan
```

### 4. Deploy

```bash
terraform apply
```

### 5. Configure DNS

After deployment, create a DNS record (CNAME or Route53 alias) pointing your domain to the ALB DNS name:

```bash
terraform output alb_dns_name
```

## Architecture

```
Internet
    │
    ▼
Application Load Balancer (Public Subnets)
    │
    ▼
ECS Tasks (Private Subnets)
    │
    ▼
RDS PostgreSQL (Private Subnets)
```

**What this module creates:**
- ECS cluster and service (Fargate)
- Application Load Balancer with HTTPS listener
- RDS PostgreSQL database (Multi-AZ)
- Security groups (ALB, ECS, RDS)
- IAM roles for ECS tasks
- Secrets Manager secrets for credentials
- CloudWatch Log Group for container logs
- Auto Scaling policies (optional)

**What you must provide:**
- VPC and subnets
- ACM certificate for HTTPS
- Domain name

## Configuration Options

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `vpc_id` | VPC ID where resources will be created | `vpc-xxxxx` |
| `private_subnet_ids` | Private subnet IDs for ECS and RDS | `["subnet-xxxxx", "subnet-yyyyy"]` |
| `public_subnet_ids` | Public subnet IDs for ALB | `["subnet-aaaaa", "subnet-bbbbb"]` |
| `domain_name` | Domain name for the application | `stategraph.example.com` |
| `certificate_arn` | ACM certificate ARN for HTTPS | `arn:aws:acm:...` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `environment` | Environment name | `production` |
| `ecs_task_cpu` | ECS task CPU units | `1024` |
| `ecs_task_memory` | ECS task memory (MB) | `2048` |
| `ecs_desired_count` | Number of ECS tasks | `2` |
| `enable_autoscaling` | Enable ECS autoscaling | `true` |
| `ecs_max_count` | Max tasks for autoscaling | `4` |
| `ecs_min_count` | Min tasks for autoscaling | `1` |
| `database_instance_class` | RDS instance type | `db.t3.medium` |
| `database_multi_az` | Enable Multi-AZ for RDS | `true` |
| `database_backup_retention_period` | Backup retention (days) | `7` |
| `stategraph_image` | Docker image | `ghcr.io/stategraph/stategraph-server:latest` |
| `log_retention_days` | CloudWatch log retention | `7` |

For a complete list of variables, see [variables.tf](./variables.tf).

## Advanced Configuration

### Using an External PostgreSQL Database

If you have an existing PostgreSQL database, set `create_database = false` and provide connection details:

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.0.0"

  # ... other required variables ...

  create_database           = false
  external_database_host    = "postgres.example.com"
  external_database_port    = 5432
  external_database_name    = "stategraph"
  external_database_username = "stategraph_user"
  external_database_password = var.database_password  # Use variable for sensitive data
}
```

### OAuth Authentication

Enable OAuth authentication with Google, GitHub, or OIDC:

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.0.0"

  # ... other required variables ...

  oauth_enabled       = true
  oauth_provider      = "google"  # or "github" or "oidc"
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret

  # For OIDC provider:
  # oauth_issuer_url = "https://accounts.google.com"
}
```

**Important**: Store OAuth credentials securely using Terraform variables, not hardcoded values.

### Development vs Production

For development environments, you can reduce costs:

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.0.0"

  # ... required variables ...

  environment                     = "development"
  ecs_desired_count               = 1
  ecs_task_cpu                    = 512
  ecs_task_memory                 = 1024
  database_instance_class         = "db.t3.micro"
  database_multi_az               = false
  enable_autoscaling              = false
  enable_deletion_protection      = false
  database_backup_retention_period = 1
}
```

### ALB Access Logs

Enable ALB access logs for compliance or debugging:

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.0.0"

  # ... other required variables ...

  alb_access_logs_enabled = true
  alb_access_logs_bucket  = "my-alb-logs-bucket"
  alb_access_logs_prefix  = "stategraph"
}
```

## Outputs

| Output | Description |
|--------|-------------|
| `alb_dns_name` | ALB DNS name (point your domain here) |
| `alb_zone_id` | ALB hosted zone ID (for Route53 alias) |
| `ecs_cluster_name` | Name of the ECS cluster |
| `ecs_service_name` | Name of the ECS service |
| `database_endpoint` | RDS database endpoint |
| `database_secret_arn` | Secrets Manager secret ARN |
| `cloudwatch_log_group_name` | CloudWatch Log Group name |

## Monitoring and Operations

### View Container Logs

```bash
aws logs tail /ecs/stategraph-production --follow
```

### View ECS Service Status

```bash
aws ecs describe-services \
  --cluster stategraph-production \
  --services stategraph-production
```

### Scale ECS Tasks Manually

```bash
aws ecs update-service \
  --cluster stategraph-production \
  --service stategraph-production \
  --desired-count 4
```

Note: If autoscaling is enabled, it will adjust the count automatically.

### Access Database Credentials

```bash
aws secretsmanager get-secret-value \
  --secret-id stategraph-database-production \
  --query SecretString --output text | jq -r '.password'
```

## Upgrading

### Update Stategraph Version

1. Update the image tag in your configuration:

```hcl
module "stategraph" {
  # ... other variables ...
  stategraph_image = "ghcr.io/stategraph/stategraph-server:v1.2.0"
}
```

2. Apply the change:

```bash
terraform apply
```

ECS will perform a rolling deployment with zero downtime.

### Update Module Version

1. Update the module reference:

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.1.0"
  # ...
}
```

2. Reinitialize and apply:

```bash
terraform init -upgrade
terraform plan
terraform apply
```

## Troubleshooting

### Tasks are not starting

Check the ECS service events:

```bash
aws ecs describe-services \
  --cluster stategraph-production \
  --services stategraph-production \
  --query 'services[0].events[0:5]'
```

Common issues:
- **Insufficient permissions**: Check IAM roles in `iam.tf`
- **Image pull errors**: Verify the image exists and is accessible
- **Health check failures**: Check container logs in CloudWatch

### Database connection issues

Verify security group rules allow ECS tasks to reach RDS:

```bash
aws ec2 describe-security-group-rules \
  --filters "Name=group-id,Values=<ecs-security-group-id>"
```

### Application not accessible

1. Verify ALB target health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

2. Check DNS record points to ALB
3. Verify ACM certificate is valid and matches your domain

## Cost Optimization

Estimated monthly costs (us-east-1, as of 2025):

**Production Configuration** (default):
- ECS Fargate (2 tasks, 1 vCPU, 2GB): ~$50
- RDS db.t3.medium (Multi-AZ): ~$120
- ALB: ~$20
- Data transfer: Variable
- **Total**: ~$190/month + data transfer

**Development Configuration**:
- ECS Fargate (1 task, 0.5 vCPU, 1GB): ~$15
- RDS db.t3.micro (Single-AZ): ~$15
- ALB: ~$20
- **Total**: ~$50/month + data transfer

Tips:
- Use Single-AZ RDS for non-production environments
- Reduce ECS task count and size for development
- Enable ALB access logs only when needed
- Adjust backup retention periods

## Security Considerations

This module follows AWS security best practices:

- **Encryption at rest**: RDS storage encrypted, Secrets Manager encrypted
- **Encryption in transit**: HTTPS enforced, TLS 1.3 preferred
- **Network isolation**: ECS tasks and RDS in private subnets
- **Least privilege**: IAM roles grant only necessary permissions
- **Secrets management**: No credentials in Terraform state or environment variables
- **Security groups**: Restrictive ingress/egress rules

Additional recommendations:
- Enable VPC Flow Logs for network monitoring
- Configure AWS Config for compliance tracking
- Use AWS WAF with the ALB for application-layer protection
- Enable GuardDuty for threat detection

## Examples

See the [examples/](./examples/) directory for complete, working examples:

- **[complete](./examples/complete/)**: Full deployment with VPC creation
- More examples coming soon

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/stategraph/stategraph/issues
- Documentation: https://stategraph.com/docs

## License

This module is part of the Stategraph project. See the main repository for license information.
