# Complete Stategraph ECS Deployment Example

This example deploys Stategraph on AWS ECS with a new VPC. It uses the module from this repository, at `../../`.

## What this example deploys

- **VPC**: public and private subnets across 3 availability zones, with NAT gateways
- **Stategraph**: the ECS service, the ALB, RDS PostgreSQL, the secrets, and the IAM roles from the module
- **Route 53 record**: optional, when `route53_zone_id` is set

## Prerequisites

1. An AWS account with permissions for ECS, RDS, ALB, IAM, Secrets Manager, CloudWatch, and VPC
2. Terraform 1.3 or later, or OpenTofu
3. A Stategraph Enterprise license key, or the intent to enter it on the setup screen
4. For HTTPS: a domain name and an ACM certificate for it in the deployment region

## Quick start

### 1. Request an ACM certificate

Skip this step for an HTTP-only trial.

```bash
aws acm request-certificate \
  --domain-name stategraph.example.com \
  --validation-method DNS \
  --region us-east-1
```

Validate it through DNS as the AWS console instructs, and note its ARN.

### 2. Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
```

Set `domain_name` and `certificate_arn` in `terraform.tfvars`. Leave both unset for an HTTP-only trial on the ALB DNS name. Keep `terraform.tfvars` out of version control: it can hold the license key and the OAuth client secret.

### 3. Deploy

```bash
terraform init
terraform plan
terraform apply
```

The apply takes 10 to 15 minutes.

### 4. Configure DNS

Point your domain at the ALB, or set `route53_zone_id` and let the example create the alias record:

```bash
terraform output alb_dns_name
terraform output alb_zone_id
```

### 5. Open Stategraph

Wait for the first start, then open the console and create the first admin account:

```bash
curl -f "$(terraform output -raw stategraph_url)/health/ready"
terraform output -raw stategraph_url
```

## Trial settings

For a short trial, the values at the end of `terraform.tfvars.example` make the stack cheaper and easy to destroy: one small task, a single-AZ `db.t3.micro`, no deletion protection, no final snapshot, and secrets that Secrets Manager removes at once.

## Using an existing VPC

Remove the `vpc` module and pass your subnets to the `stategraph` module:

```hcl
module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=v2.0.0"

  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # ...
}
```

## Monitoring

```bash
aws logs tail "$(terraform output -raw cloudwatch_log_group_name)" --follow

aws ecs describe-services \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --services "$(terraform output -raw ecs_service_name)"
```

## Upgrading

Set `stategraph_image` in `terraform.tfvars` to the new tag and apply. ECS does a rolling deployment.

## Cleanup

```bash
terraform destroy
```

This deletes the database. With `database_skip_final_snapshot = false`, the default, RDS keeps a final snapshot.

## Next steps

- [Import your Terraform state](https://stategraph.com/docs/get-started/quickstart/import-state)
- [Enable Orchestration](https://stategraph.com/docs/admin/self-hosting/orchestration)
- [Gap analysis](https://stategraph.com/docs/infrastructure-as-a-database/query/gap-analysis)
