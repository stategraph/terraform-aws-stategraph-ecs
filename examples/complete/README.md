# Complete Stategraph ECS Deployment Example

This example demonstrates a complete deployment of Stategraph on AWS ECS, including VPC creation.

## What This Example Deploys

- **VPC**: New VPC with public and private subnets across 3 availability zones
- **NAT Gateway**: For private subnet internet access (single NAT for dev, multi-NAT for prod)
- **Stategraph ECS**: Complete application stack (ECS, RDS, ALB, security groups, IAM)

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** 1.0 or higher
3. **ACM Certificate** for your domain in the deployment region
4. **Domain Name** where Stategraph will be accessible

## Quick Start

### 1. Create ACM Certificate

Before deploying, create an SSL certificate in AWS Certificate Manager:

```bash
# Request certificate (replace with your domain)
aws acm request-certificate \
  --domain-name stategraph.example.com \
  --validation-method DNS \
  --region us-east-1

# Note the CertificateArn from the output
```

Follow AWS Console instructions to validate the certificate via DNS.

### 2. Configure Variables

Copy the example variables file and customize it:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `domain_name`: Your domain (e.g., `stategraph.example.com`)
- `certificate_arn`: ARN from step 1
- Other settings as needed

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply
```

### 4. Configure DNS

After deployment, create a DNS record:

```bash
# Get the ALB DNS name
terraform output alb_dns_name

# Create CNAME record pointing your domain to this DNS name
# Or use Route53 alias record (recommended):
# terraform output alb_zone_id
```

### 5. Access Stategraph

After DNS propagation (5-10 minutes), access Stategraph at:

```
https://your-domain.example.com
```

## Configuration Examples

### Production Environment

```hcl
environment                      = "production"
ecs_desired_count                = 2
ecs_task_cpu                     = 1024
ecs_task_memory                  = 2048
database_instance_class          = "db.t3.medium"
database_multi_az                = true
enable_autoscaling               = true
enable_deletion_protection       = true
database_backup_retention_period = 7
```

**Estimated cost**: ~$190/month

### Development Environment

```hcl
environment                      = "development"
ecs_desired_count                = 1
ecs_task_cpu                     = 512
ecs_task_memory                  = 1024
database_instance_class          = "db.t3.micro"
database_multi_az                = false
enable_autoscaling               = false
enable_deletion_protection       = false
database_backup_retention_period = 1
```

**Estimated cost**: ~$50/month

### With OAuth Authentication

```hcl
oauth_enabled       = true
oauth_provider      = "google"  # or "github" or "oidc"
oauth_client_id     = var.oauth_client_id
oauth_client_secret = var.oauth_client_secret

# For OIDC:
# oauth_issuer_url = "https://accounts.google.com"
```

**Note**: Store OAuth credentials in a separate `secrets.tfvars` file and add it to `.gitignore`.

## Using Existing VPC

If you already have a VPC, remove the VPC module and reference your existing resources:

```hcl
module "stategraph" {
  source = "github.com/stategraph/stategraph//terraform/aws-ecs?ref=v1.0.0"

  vpc_id             = "vpc-xxxxx"  # Your existing VPC
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # ... rest of configuration
}
```

## Automatic DNS with Route53

Uncomment the `aws_route53_record` resource in `main.tf` and add to `terraform.tfvars`:

```hcl
route53_zone_id = "Z1234567890ABC"
```

Terraform will automatically create the DNS record.

## Monitoring

### View Container Logs

```bash
aws logs tail $(terraform output -raw cloudwatch_log_group) --follow
```

### Check Service Health

```bash
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name)
```

### View RDS Metrics

```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name CPUUtilization \
  --dimensions Name=DBInstanceIdentifier,Value=stategraph-production \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

## Upgrading

### Update Stategraph Version

Edit `terraform.tfvars`:

```hcl
stategraph_image = "ghcr.io/stategraph/stategraph-server:v1.2.0"
```

Apply:

```bash
terraform apply
```

ECS performs a rolling deployment with zero downtime.

## Troubleshooting

### Tasks Not Starting

Check ECS service events:

```bash
aws ecs describe-services \
  --cluster $(terraform output -raw ecs_cluster_name) \
  --services $(terraform output -raw ecs_service_name) \
  --query 'services[0].events[0:5]'
```

### Database Connection Issues

Verify security group rules:

```bash
terraform state show module.stategraph.aws_security_group.ecs
terraform state show module.stategraph.aws_security_group.rds[0]
```

### ALB Health Checks Failing

Check container logs:

```bash
aws logs tail $(terraform output -raw cloudwatch_log_group) --follow
```

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete all data, including the database. Make sure you have backups.

## Cost Optimization

- **Development**: Use single-AZ RDS, smaller instance types, disable autoscaling
- **Production**: Use Multi-AZ RDS, enable autoscaling, configure backup retention
- **All Environments**: Monitor CloudWatch metrics, right-size resources based on usage

## Next Steps

- Configure [gap analysis](https://stategraph.com/docs/features/gap-analysis)
- Set up [Terraform state backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
- Enable [AWS WAF](https://aws.amazon.com/waf/) for application protection
- Configure [CloudWatch alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)

## Support

- Documentation: https://stategraph.com/docs
- Issues: https://github.com/stategraph/stategraph/issues
