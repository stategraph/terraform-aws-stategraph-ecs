# Stategraph ECS Terraform Module

Deploy the Stategraph Enterprise server on AWS ECS Fargate, behind an Application Load Balancer, with RDS PostgreSQL. The module implements the [Amazon ECS self-hosting guide](https://stategraph.com/docs/admin/self-hosting/ecs).

## What the module creates

- ECS cluster, Fargate task definition, and service, with a deployment circuit breaker and autoscaling
- Application Load Balancer. With a certificate: HTTPS on 443 and a redirect from 80. Without one: HTTP on 80
- RDS PostgreSQL 17, Multi-AZ, encrypted, with automated backups and deletion protection
- Secrets Manager secrets for the database credentials and for the server secrets
- IAM roles for the task execution and for the running server
- Security groups for the ALB, the tasks, and RDS
- CloudWatch log group for the container logs, and Container Insights on the cluster

```text
Internet
    │
    ▼
Application Load Balancer (public subnets, 443 and 80)
    │
    ▼
ECS Fargate tasks (private subnets, port 8080)
    │
    ▼
RDS PostgreSQL (private subnets, 5432)
```

## Prerequisites

- A VPC with private subnets for the tasks and RDS, behind a NAT gateway, and subnets for the ALB, in at least two availability zones each
- Terraform 1.3 or later, or OpenTofu, with AWS provider 6.0 or later
- A Stategraph Enterprise license key. The setup screen asks for it when the module does not pass one. [Contact Stategraph](https://stategraph.com/contact) for a key
- For HTTPS: a domain name and an ACM certificate for it, in the deployment region

## Quick start

```hcl
module "stategraph" {
  source = "github.com/stategraph/terraform-aws-stategraph-ecs?ref=v2.0.0"

  # Network
  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
  public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]

  # Domain and certificate
  domain_name     = "stategraph.example.com"
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/xxxxx"

  # License key, stored in Secrets Manager
  license_key = var.stategraph_license_key

  environment = "production"

  tags = {
    Project   = "Stategraph"
    ManagedBy = "Terraform"
  }
}

output "stategraph_url" {
  value = module.stategraph.stategraph_url
}

output "alb_dns_name" {
  description = "Create a CNAME record pointing your domain here"
  value       = module.stategraph.alb_dns_name
}
```

1. Run `terraform init`, `terraform plan`, and `terraform apply`. The apply takes 10 to 15 minutes.
2. Point `domain_name` at the ALB: a CNAME to `alb_dns_name`, or a Route 53 alias record with `alb_zone_id`.
3. Wait for the first start. Migrations run before the server accepts requests:

```bash
curl -f "$(terraform output -raw stategraph_url)/health/ready"
```

4. Open the URL and create the first admin account on the setup screen. The screen asks for the license key first when `license_key` is not set.

### Trial without DNS

Leave `domain_name` and `certificate_arn` unset. The ALB then serves HTTP only, and `stategraph_url` is `http://<alb_dns_name>`. Cookies do not get the `Secure` flag, so use this for a trial only. See the [complete example](./examples/complete/) for trial settings that are cheap and easy to destroy.

## First start

At each start, Stategraph migrates the `stategraph` database, then serves requests. The module sets the health checks for this window:

| Check | Path | Setting |
|-------|------|---------|
| ECS container health check | `/health/live` | Answers 200 as soon as the web server is up. Start period 120 seconds |
| ALB target group | `/health/ready` | Answers 200 only when the server has migrated and serves requests |
| ECS service | | Health check grace period 300 seconds |
| Container stop | | Stop timeout 60 seconds, so that the server finishes the requests in progress |

A first start on a large database can take minutes. Raise `health_check_grace_period_seconds` if the service replaces tasks during a long migration. See [Health checks](https://stategraph.com/docs/admin/operations/health-checks).

## Configuration

Stategraph reads its settings from [environment variables](https://stategraph.com/docs/admin/operations/environment-variables). The module sets these on the server container:

| Variable | Value |
|----------|-------|
| `STATEGRAPH_UI_BASE`, `STATEGRAPH_OAUTH_REDIRECT_BASE` | `https://<domain_name>`, or `http://<alb_dns_name>` without a certificate |
| `DB_HOST`, `DB_PORT`, `DB_NAME` | The RDS instance, or the external database |
| `DB_USER`, `DB_PASS` | From the database secret |
| `STATEGRAPH_OAUTH_COOKIE_SECRET` | From the server secret. Generated once, shared by every task |
| `STATEGRAPH_LICENSE_KEY` | From the server secret, when `license_key` is set |
| `STATEGRAPH_OAUTH_*` | When `oauth_enabled` is true |
| `STATEGRAPH_COST_ENABLED`, `PRICING_DB_*` | When `cost_enabled` is true |
| `STATEGRAPH_SECURITY` | When `security_scanning_enabled` is true |

Pass any other variable with `extra_environment`, and any other secret with `extra_secrets`:

```hcl
module "stategraph" {
  # ...

  extra_environment = [
    { name = "STATEGRAPH_DEFAULT_TENANT_NAME", value = "Platform" },
  ]

  extra_secrets = [
    { name = "GITHUB_APP_PEM", value_from = aws_secretsmanager_secret.github_app.arn },
  ]
}
```

Each `value_from` is a Secrets Manager secret ARN, with an optional `:json-key::` suffix. The task execution role gets read access to each secret. After you change the value of a secret, force a new deployment so that the tasks read it:

```bash
aws ecs update-service \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --service "$(terraform output -raw ecs_service_name)" \
  --force-new-deployment
```

## Authentication

Local email and password sign-in is on by default. For Google or OIDC single sign-on:

```hcl
module "stategraph" {
  # ...

  oauth_enabled       = true
  oauth_provider      = "google" # or "oidc"
  oauth_client_id     = var.oauth_client_id
  oauth_client_secret = var.oauth_client_secret
  oauth_email_domain  = "example.com"

  # OIDC only
  # oauth_issuer_url = "https://login.example.com"
}
```

In your provider, register the callback URL `https://<domain_name>/oauth2/google/callback` for Google, or `https://<domain_name>/oauth2/oidc/callback` for OIDC. The module keeps the client secret in Secrets Manager.

Set `oauth_email_domain` on any deployment that the internet can reach. Without it, any identity that the provider authenticates can sign in, and the first one to sign in becomes an instance admin.

The module generates one cookie secret and passes it to every task, so that sign-in works with several tasks and sessions survive a deployment. To bring your own, set `oauth_cookie_secret` to a value of 16, 24, or 32 characters. See [Access control](https://stategraph.com/docs/admin/access-control).

## Cost estimation

```hcl
cost_enabled = true
```

The module sets `STATEGRAPH_COST_ENABLED=true` and points `PRICING_DB_*` at the same database server, with the database credentials and `PRICING_DB_SSLMODE=require`. At the first start, Stategraph creates the `cloud_pricing` database with the master user and loads the price book in the background. The first load downloads several hundred MB. Allow a few minutes and disk space on RDS. See [Enable cost estimation](https://stategraph.com/docs/admin/self-hosting/cost).

## Security scanning

```hcl
security_scanning_enabled = true
```

The module sets `STATEGRAPH_SECURITY=1`. See [Enable security scanning](https://stategraph.com/docs/admin/self-hosting/security-scanning).

## Orchestration

Stategraph Orchestration is off by default. This version of the module has no dedicated variables for it. Turn it on with `extra_environment` and `extra_secrets`, with the variables from [Enable Orchestration](https://stategraph.com/docs/admin/self-hosting/orchestration):

```hcl
module "stategraph" {
  # ...

  extra_environment = [
    { name = "STATEGRAPH_ORCHESTRATION_ENABLED", value = "true" },
    { name = "TERRAT_API_BASE", value = "https://stategraph.example.com/api" },
    { name = "TERRAT_UI_BASE", value = "https://stategraph.example.com" },
    { name = "TERRAT_WEB_BASE_URL", value = "https://stategraph.example.com" },
    { name = "GITHUB_APP_URL", value = "https://github.com/apps/your-app" },
  ]

  extra_secrets = [
    { name = "STATEGRAPH_FDW_PASSWORD", value_from = "${aws_secretsmanager_secret.orchestration.arn}:fdw_password::" },
    { name = "GITHUB_APP_ID", value_from = "${aws_secretsmanager_secret.orchestration.arn}:github_app_id::" },
    { name = "GITHUB_APP_CLIENT_ID", value_from = "${aws_secretsmanager_secret.orchestration.arn}:github_app_client_id::" },
    { name = "GITHUB_APP_CLIENT_SECRET", value_from = "${aws_secretsmanager_secret.orchestration.arn}:github_app_client_secret::" },
    { name = "GITHUB_APP_PEM", value_from = "${aws_secretsmanager_secret.orchestration.arn}:github_app_pem::" },
    { name = "GITHUB_WEBHOOK_SECRET", value_from = "${aws_secretsmanager_secret.orchestration.arn}:github_webhook_secret::" },
  ]
}
```

On the RDS instance, the master user is a member of `rds_superuser`, so Orchestration creates the `terrateam` database and the `postgres_fdw` bridge at start. Set the password of the read role one time, with the same value as `STATEGRAPH_FDW_PASSWORD`:

```sql
ALTER ROLE stategraph_mql LOGIN PASSWORD '<fdw-password>';
```

Then set the webhook URL of the GitHub App to `https://<domain_name>/api/github/v1/events`.

## Gap analysis

The server runs gap analysis with the credentials of the ECS task role. Attach a read-only policy to it:

```hcl
ecs_task_role_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
```

See [Gap analysis](https://stategraph.com/docs/infrastructure-as-a-database/query/gap-analysis).

## External PostgreSQL

```hcl
module "stategraph" {
  # ...

  create_database            = false
  external_database_host     = "postgres.internal.example.com"
  external_database_port     = 5432
  external_database_name     = "stategraph"
  external_database_username = var.database_username
  external_database_password = var.database_password
}
```

The `stategraph` database must exist before the first start. The tasks need network access to the server on the given port. The module stores the credentials in Secrets Manager.

## Network options

| Variable | Use |
|----------|-----|
| `alb_internal = true` | An internal ALB. Pass private subnets in `public_subnet_ids` |
| `alb_ingress_cidrs` | CIDR blocks allowed to reach the ALB, for example a VPC or office range |
| `cpu_architecture = "ARM64"` | Graviton Fargate tasks. The Stategraph image ships both architectures |

## Upgrading Stategraph

Change the image tag and apply. ECS does a rolling deployment, and the ALB routes only to tasks that answer `/health/ready`:

```hcl
stategraph_image = "ghcr.io/stategraph/stategraph-server:3.1.0"
```

Read the release notes of the versions that you skip on the [releases page](https://github.com/stategraph/releases/releases). See [Upgrades](https://stategraph.com/docs/admin/operations/upgrades).

## Upgrading the module from 1.x

Version 2.0.0 changes the server contract and some defaults. Review the plan before you apply:

- The OAuth variables now set the `STATEGRAPH_OAUTH_*` names that the server reads. The `github` provider is gone: only `google` and `oidc` exist. The `stategraph-oauth-<environment>` secret is replaced by `stategraph-server-<environment>`, which also holds the cookie secret and the license key.
- The health checks changed: the target group probes `/health/ready`, the container probes `/health/live`, and the service has a 300 second grace period.
- `database_engine_version` defaults to `17`. An existing instance on PostgreSQL 16 needs `database_engine_version = "16"`, then a separate major version upgrade.
- `database_deletion_protection` defaults to `true`.
- `alb_ingress_cidrs` replaces the fixed `0.0.0.0/0` rules, and the HTTPS listener is optional. `moved` blocks keep the existing resources.
- `alb_idle_timeout` defaults to 120 seconds.
- `container_port` is gone. The image listens on 8080.
- The AWS provider must be 6.0 or later.
- The task definition changes, so the apply starts a new deployment.

## Operations

```bash
# Container logs
aws logs tail "$(terraform output -raw cloudwatch_log_group_name)" --follow

# Service status and events
aws ecs describe-services \
  --cluster "$(terraform output -raw ecs_cluster_name)" \
  --services "$(terraform output -raw ecs_service_name)"

# Database password
aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw database_secret_arn)" \
  --query SecretString --output text | jq -r '.password'
```

Container Insights is on. In the CloudWatch console, **Container Insights > ECS Clusters** shows CPU, memory, response time, and request count. See [Observability](https://stategraph.com/docs/admin/operations/observability).

## Troubleshooting

Check the container log first.

- **A task stops right after it starts.** A secret that the task references has no value, or a required variable is missing. The log says which.
- **502 or 503 from the ALB, and 502 from `/health/ready`.** The task is still migrating. On the first deploy, wait a few minutes.
- **Sign-in redirects to the wrong URL.** `domain_name` changed. Apply, then force a new deployment, so that the tasks read the new `STATEGRAPH_UI_BASE`.
- **The RDS create fails on the engine version.** RDS retires minor versions. Keep `database_engine_version` at a major version such as `17`.
- **OAuth sign-in fails with several tasks.** Each task must get the same cookie secret. Keep `oauth_cookie_secret` unset, or set the same value on every task.

## Development

```bash
make check       # fmt-check, validate, lint, docs-check, test
make test        # tofu test, with a mock AWS provider, no credentials needed
make docs        # regenerate the reference below with terraform-docs
```

The checks need `tofu`, `tflint`, and `terraform-docs`. CI runs `make check`.

## Reference

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_appautoscaling_policy.ecs_cpu](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_policy.ecs_memory](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_policy) | resource |
| [aws_appautoscaling_target.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appautoscaling_target) | resource |
| [aws_cloudwatch_log_group.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_db_instance.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_subnet_group.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_ecs_cluster.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster) | resource |
| [aws_ecs_service.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service) | resource |
| [aws_ecs_task_definition.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition) | resource |
| [aws_iam_role.ecs_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.ecs_task](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.ecs_execution_secrets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.ecs_task_app](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.ecs_execution](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.ecs_task_extra](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lb.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_secretsmanager_secret.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.database](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_secretsmanager_secret_version.stategraph](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_security_group.alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.rds](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.alb_all](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_dns](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_external_postgres](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ecs_postgres](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.alb_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.ecs_from_alb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.rds_from_ecs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_password.cookie_secret](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [random_password.database](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/password) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alb_access_logs_bucket"></a> [alb\_access\_logs\_bucket](#input\_alb\_access\_logs\_bucket) | S3 bucket for ALB access logs, required when alb\_access\_logs\_enabled is true | `string` | `""` | no |
| <a name="input_alb_access_logs_enabled"></a> [alb\_access\_logs\_enabled](#input\_alb\_access\_logs\_enabled) | Enable ALB access logs | `bool` | `false` | no |
| <a name="input_alb_access_logs_prefix"></a> [alb\_access\_logs\_prefix](#input\_alb\_access\_logs\_prefix) | Prefix for ALB access logs in S3 | `string` | `"alb-logs"` | no |
| <a name="input_alb_idle_timeout"></a> [alb\_idle\_timeout](#input\_alb\_idle\_timeout) | ALB idle timeout in seconds. The server closes idle API requests after 120 seconds | `number` | `120` | no |
| <a name="input_alb_ingress_cidrs"></a> [alb\_ingress\_cidrs](#input\_alb\_ingress\_cidrs) | CIDR blocks allowed to reach the ALB on ports 80 and 443 | `list(string)` | <pre>[<br/>  "0.0.0.0/0"<br/>]</pre> | no |
| <a name="input_alb_internal"></a> [alb\_internal](#input\_alb\_internal) | Create an internal ALB. Pass private subnets in public\_subnet\_ids when true | `bool` | `false` | no |
| <a name="input_autoscaling_cpu_threshold"></a> [autoscaling\_cpu\_threshold](#input\_autoscaling\_cpu\_threshold) | CPU percentage target for autoscaling | `number` | `70` | no |
| <a name="input_autoscaling_memory_threshold"></a> [autoscaling\_memory\_threshold](#input\_autoscaling\_memory\_threshold) | Memory percentage target for autoscaling | `number` | `80` | no |
| <a name="input_certificate_arn"></a> [certificate\_arn](#input\_certificate\_arn) | ACM certificate ARN for HTTPS on the ALB. Requires domain\_name. When null, the ALB serves HTTP only | `string` | `null` | no |
| <a name="input_container_health_check_path"></a> [container\_health\_check\_path](#input\_container\_health\_check\_path) | ECS container health check path. /health/live answers 200 as soon as the web server is up, also during migrations | `string` | `"/health/live"` | no |
| <a name="input_container_health_check_start_period"></a> [container\_health\_check\_start\_period](#input\_container\_health\_check\_start\_period) | Seconds before ECS counts container health check failures. Covers the migrations at the first start | `number` | `120` | no |
| <a name="input_container_stop_timeout"></a> [container\_stop\_timeout](#input\_container\_stop\_timeout) | Seconds ECS waits for the container to stop before it kills it. Stategraph finishes the requests in progress within 60 seconds | `number` | `60` | no |
| <a name="input_cost_enabled"></a> [cost\_enabled](#input\_cost\_enabled) | Enable cost estimation. The price book is loaded into a cloud\_pricing database on the same PostgreSQL server | `bool` | `false` | no |
| <a name="input_cpu_architecture"></a> [cpu\_architecture](#input\_cpu\_architecture) | CPU architecture of the Fargate tasks: X86\_64 or ARM64. The Stategraph image ships both | `string` | `"X86_64"` | no |
| <a name="input_create_database"></a> [create\_database](#input\_create\_database) | Create an RDS PostgreSQL instance. When false, set the external\_database\_* variables | `bool` | `true` | no |
| <a name="input_database_allocated_storage"></a> [database\_allocated\_storage](#input\_database\_allocated\_storage) | Allocated storage for RDS in GB | `number` | `100` | no |
| <a name="input_database_backup_retention_period"></a> [database\_backup\_retention\_period](#input\_database\_backup\_retention\_period) | Backup retention period in days | `number` | `7` | no |
| <a name="input_database_deletion_protection"></a> [database\_deletion\_protection](#input\_database\_deletion\_protection) | Enable deletion protection on the RDS instance | `bool` | `true` | no |
| <a name="input_database_engine_version"></a> [database\_engine\_version](#input\_database\_engine\_version) | PostgreSQL engine version of the RDS instance. A major version such as 17 lets RDS pick the current minor version | `string` | `"17"` | no |
| <a name="input_database_instance_class"></a> [database\_instance\_class](#input\_database\_instance\_class) | RDS instance class | `string` | `"db.t3.medium"` | no |
| <a name="input_database_max_allocated_storage"></a> [database\_max\_allocated\_storage](#input\_database\_max\_allocated\_storage) | Maximum allocated storage for RDS storage autoscaling in GB | `number` | `500` | no |
| <a name="input_database_multi_az"></a> [database\_multi\_az](#input\_database\_multi\_az) | Enable Multi-AZ for RDS | `bool` | `true` | no |
| <a name="input_database_name"></a> [database\_name](#input\_database\_name) | Name of the PostgreSQL database | `string` | `"stategraph"` | no |
| <a name="input_database_skip_final_snapshot"></a> [database\_skip\_final\_snapshot](#input\_database\_skip\_final\_snapshot) | Skip the final snapshot when the RDS instance is destroyed. Use for trials only | `bool` | `false` | no |
| <a name="input_database_username"></a> [database\_username](#input\_database\_username) | Master username of the RDS instance | `string` | `"stategraph"` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Public host name of Stategraph, for example stategraph.example.com. Point its DNS record at the ALB. When null, the ALB DNS name is used and the deployment is HTTP only | `string` | `null` | no |
| <a name="input_ecs_desired_count"></a> [ecs\_desired\_count](#input\_ecs\_desired\_count) | Desired number of ECS tasks | `number` | `2` | no |
| <a name="input_ecs_max_count"></a> [ecs\_max\_count](#input\_ecs\_max\_count) | Maximum number of ECS tasks for autoscaling | `number` | `4` | no |
| <a name="input_ecs_min_count"></a> [ecs\_min\_count](#input\_ecs\_min\_count) | Minimum number of ECS tasks for autoscaling | `number` | `1` | no |
| <a name="input_ecs_task_cpu"></a> [ecs\_task\_cpu](#input\_ecs\_task\_cpu) | Fargate task CPU units (256, 512, 1024, 2048, 4096) | `number` | `1024` | no |
| <a name="input_ecs_task_memory"></a> [ecs\_task\_memory](#input\_ecs\_task\_memory) | Fargate task memory in MB (512, 1024, 2048, 4096, 8192, 16384, 30720) | `number` | `2048` | no |
| <a name="input_ecs_task_role_policy_arns"></a> [ecs\_task\_role\_policy\_arns](#input\_ecs\_task\_role\_policy\_arns) | IAM policy ARNs to attach to the task role, for example ReadOnlyAccess for gap analysis of the AWS account | `list(string)` | `[]` | no |
| <a name="input_enable_autoscaling"></a> [enable\_autoscaling](#input\_enable\_autoscaling) | Enable ECS autoscaling on CPU and memory | `bool` | `true` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | Enable deletion protection on the ALB | `bool` | `true` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name, used in every resource name. Lowercase letters, digits, and hyphens, at most 21 characters | `string` | `"production"` | no |
| <a name="input_external_database_host"></a> [external\_database\_host](#input\_external\_database\_host) | External PostgreSQL host | `string` | `""` | no |
| <a name="input_external_database_name"></a> [external\_database\_name](#input\_external\_database\_name) | External PostgreSQL database name. The database must exist before the first start | `string` | `""` | no |
| <a name="input_external_database_password"></a> [external\_database\_password](#input\_external\_database\_password) | External PostgreSQL password | `string` | `""` | no |
| <a name="input_external_database_port"></a> [external\_database\_port](#input\_external\_database\_port) | External PostgreSQL port | `number` | `5432` | no |
| <a name="input_external_database_username"></a> [external\_database\_username](#input\_external\_database\_username) | External PostgreSQL username | `string` | `""` | no |
| <a name="input_extra_environment"></a> [extra\_environment](#input\_extra\_environment) | Additional environment variables for the server container, for example Orchestration settings | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_extra_secrets"></a> [extra\_secrets](#input\_extra\_secrets) | Additional secrets for the server container. Each value\_from is a Secrets Manager secret ARN, with an optional :json-key:: suffix. The task execution role gets read access to each secret | <pre>list(object({<br/>    name       = string<br/>    value_from = string<br/>  }))</pre> | `[]` | no |
| <a name="input_health_check_grace_period_seconds"></a> [health\_check\_grace\_period\_seconds](#input\_health\_check\_grace\_period\_seconds) | Seconds the ECS service ignores ALB health check failures after a task starts. Must cover the migration time at the first start | `number` | `300` | no |
| <a name="input_health_check_healthy_threshold"></a> [health\_check\_healthy\_threshold](#input\_health\_check\_healthy\_threshold) | Consecutive ALB health check successes before a target is healthy | `number` | `2` | no |
| <a name="input_health_check_interval"></a> [health\_check\_interval](#input\_health\_check\_interval) | Health check interval in seconds, for the ALB and the container | `number` | `30` | no |
| <a name="input_health_check_path"></a> [health\_check\_path](#input\_health\_check\_path) | ALB target group health check path. /health/ready answers 200 only when the server has migrated and serves requests | `string` | `"/health/ready"` | no |
| <a name="input_health_check_timeout"></a> [health\_check\_timeout](#input\_health\_check\_timeout) | Health check timeout in seconds, for the ALB and the container | `number` | `5` | no |
| <a name="input_health_check_unhealthy_threshold"></a> [health\_check\_unhealthy\_threshold](#input\_health\_check\_unhealthy\_threshold) | Consecutive health check failures before a target is unhealthy, for the ALB and the container | `number` | `5` | no |
| <a name="input_license_key"></a> [license\_key](#input\_license\_key) | Stategraph Enterprise license key, stored in Secrets Manager and passed as STATEGRAPH\_LICENSE\_KEY. When null, the setup screen asks for the key | `string` | `null` | no |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch Logs retention period in days | `number` | `7` | no |
| <a name="input_oauth_client_id"></a> [oauth\_client\_id](#input\_oauth\_client\_id) | OAuth client ID | `string` | `""` | no |
| <a name="input_oauth_client_secret"></a> [oauth\_client\_secret](#input\_oauth\_client\_secret) | OAuth client secret, stored in Secrets Manager | `string` | `""` | no |
| <a name="input_oauth_cookie_secret"></a> [oauth\_cookie\_secret](#input\_oauth\_cookie\_secret) | Secret that signs the session and CSRF cookies on every task: 16, 24, or 32 characters. When null, the module generates one and stores it in Secrets Manager | `string` | `null` | no |
| <a name="input_oauth_display_name"></a> [oauth\_display\_name](#input\_oauth\_display\_name) | Provider name on the sign-in button. When null, the server default applies | `string` | `null` | no |
| <a name="input_oauth_email_domain"></a> [oauth\_email\_domain](#input\_oauth\_email\_domain) | Email domain that can sign in through OAuth. When null, the server default applies and any identity the provider authenticates can sign in | `string` | `null` | no |
| <a name="input_oauth_enabled"></a> [oauth\_enabled](#input\_oauth\_enabled) | Enable Google or OIDC single sign-on. Local email and password sign-in is on when this is false | `bool` | `false` | no |
| <a name="input_oauth_issuer_url"></a> [oauth\_issuer\_url](#input\_oauth\_issuer\_url) | OIDC issuer URL, required when oauth\_provider is oidc. The provider must serve {issuer}/.well-known/openid-configuration | `string` | `""` | no |
| <a name="input_oauth_provider"></a> [oauth\_provider](#input\_oauth\_provider) | Sign-in provider when oauth\_enabled is true: google or oidc | `string` | `""` | no |
| <a name="input_private_subnet_ids"></a> [private\_subnet\_ids](#input\_private\_subnet\_ids) | Private subnet IDs for the ECS tasks and RDS | `list(string)` | n/a | yes |
| <a name="input_public_subnet_ids"></a> [public\_subnet\_ids](#input\_public\_subnet\_ids) | Subnet IDs for the Application Load Balancer. Public subnets for an internet-facing ALB, private subnets when alb\_internal is true | `list(string)` | n/a | yes |
| <a name="input_secrets_recovery_window_in_days"></a> [secrets\_recovery\_window\_in\_days](#input\_secrets\_recovery\_window\_in\_days) | Days Secrets Manager keeps a deleted secret before it removes it: 0 for at once, or 7 to 30. Use 0 for trials that are created and destroyed often | `number` | `7` | no |
| <a name="input_security_scanning_enabled"></a> [security\_scanning\_enabled](#input\_security\_scanning\_enabled) | Enable security scanning of states with checkov | `bool` | `false` | no |
| <a name="input_stategraph_image"></a> [stategraph\_image](#input\_stategraph\_image) | Stategraph server image. Pin a release tag in production | `string` | `"ghcr.io/stategraph/stategraph-server:3.1.0"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where Stategraph is deployed | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_alb_arn"></a> [alb\_arn](#output\_alb\_arn) | ARN of the Application Load Balancer |
| <a name="output_alb_dns_name"></a> [alb\_dns\_name](#output\_alb\_dns\_name) | DNS name of the Application Load Balancer |
| <a name="output_alb_zone_id"></a> [alb\_zone\_id](#output\_alb\_zone\_id) | Zone ID of the Application Load Balancer, for Route 53 alias records |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the CloudWatch Log Group for the container logs |
| <a name="output_database_endpoint"></a> [database\_endpoint](#output\_database\_endpoint) | Endpoint of the RDS database, empty with an external database |
| <a name="output_database_name"></a> [database\_name](#output\_database\_name) | Name of the database |
| <a name="output_database_secret_arn"></a> [database\_secret\_arn](#output\_database\_secret\_arn) | ARN of the Secrets Manager secret with the database credentials |
| <a name="output_ecs_cluster_id"></a> [ecs\_cluster\_id](#output\_ecs\_cluster\_id) | ID of the ECS cluster |
| <a name="output_ecs_cluster_name"></a> [ecs\_cluster\_name](#output\_ecs\_cluster\_name) | Name of the ECS cluster |
| <a name="output_ecs_service_id"></a> [ecs\_service\_id](#output\_ecs\_service\_id) | ID of the ECS service |
| <a name="output_ecs_service_name"></a> [ecs\_service\_name](#output\_ecs\_service\_name) | Name of the ECS service |
| <a name="output_ecs_task_definition_arn"></a> [ecs\_task\_definition\_arn](#output\_ecs\_task\_definition\_arn) | ARN of the ECS task definition |
| <a name="output_ecs_task_execution_role_arn"></a> [ecs\_task\_execution\_role\_arn](#output\_ecs\_task\_execution\_role\_arn) | ARN of the ECS task execution role |
| <a name="output_ecs_task_role_arn"></a> [ecs\_task\_role\_arn](#output\_ecs\_task\_role\_arn) | ARN of the ECS task role |
| <a name="output_security_group_alb_id"></a> [security\_group\_alb\_id](#output\_security\_group\_alb\_id) | ID of the ALB security group |
| <a name="output_security_group_ecs_id"></a> [security\_group\_ecs\_id](#output\_security\_group\_ecs\_id) | ID of the ECS tasks security group |
| <a name="output_security_group_rds_id"></a> [security\_group\_rds\_id](#output\_security\_group\_rds\_id) | ID of the RDS security group, empty with an external database |
| <a name="output_stategraph_secret_arn"></a> [stategraph\_secret\_arn](#output\_stategraph\_secret\_arn) | ARN of the Secrets Manager secret with the cookie secret, the license key, and the OAuth client secret |
| <a name="output_stategraph_url"></a> [stategraph\_url](#output\_stategraph\_url) | URL of the Stategraph console, the value of STATEGRAPH\_UI\_BASE |
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | ARN of the ALB target group |
<!-- END_TF_DOCS -->

## Support

- Documentation: https://stategraph.com/docs/admin/self-hosting/ecs
- Issues: https://github.com/stategraph/terraform-aws-stategraph-ecs/issues

## License

Apache License 2.0. See [LICENSE](./LICENSE).
