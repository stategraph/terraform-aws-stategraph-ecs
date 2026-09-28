# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Planned as 2.0.0. The module now follows the Stategraph 3.x server contract.

### Changed

- The default image is `ghcr.io/stategraph/stategraph-server:3.1.0`. Pin a release tag in production.
- OAuth settings set `STATEGRAPH_OAUTH_TYPE`, `STATEGRAPH_OAUTH_CLIENT_ID`, `STATEGRAPH_OAUTH_CLIENT_SECRET`, `STATEGRAPH_OAUTH_OIDC_ISSUER_URL`, and `STATEGRAPH_OAUTH_REDIRECT_BASE`, the names the server reads. The `github` provider is removed: the server supports `google` and `oidc`.
- The `stategraph-oauth-<environment>` secret is replaced by `stategraph-server-<environment>`, which holds the cookie secret, the license key, and the OAuth client secret.
- The ALB target group probes `/health/ready`, the container probes `/health/live` with a 120 second start period, and the ECS service has a 300 second health check grace period.
- The container has a 60 second stop timeout.
- `database_engine_version` replaces the fixed `16.3`, defaults to `17`, and lets RDS apply minor upgrades.
- The generated database password excludes the characters RDS rejects.
- `DB_PORT` and the database security group rules use the port the RDS instance reports, in place of a fixed 5432.
- `database_deletion_protection` defaults to `true`, and snapshots get the instance tags.
- `alb_ingress_cidrs` replaces the fixed `0.0.0.0/0` ingress rules. `moved` blocks keep the existing rules.
- The HTTPS listener exists only when `certificate_arn` is set. A `moved` block keeps the existing listener.
- The ALB drops invalid header fields.
- `alb_idle_timeout` defaults to 120 seconds.
- The task definition sets `hostPort`, `mountPoints`, `systemControls`, and `volumesFrom`, so plans no longer show phantom changes.
- The AWS provider must be 6.0 or later. Terraform 1.3 or later.
- The example uses the module from the working tree, the VPC module 6.x, and creates the Route 53 record when `route53_zone_id` is set.
- CI runs `make check`: format, validate, lint, docs, and tests.

### Added

- `license_key`, stored in Secrets Manager and passed as `STATEGRAPH_LICENSE_KEY`.
- `oauth_email_domain`, `oauth_display_name`, and `oauth_cookie_secret`. Without `oauth_cookie_secret`, the module generates one cookie secret and shares it with every task.
- `cost_enabled`, which sets `STATEGRAPH_COST_ENABLED` and points `PRICING_DB_*` at the database server over TLS.
- `security_scanning_enabled`, which sets `STATEGRAPH_SECURITY=1`.
- `extra_environment` and `extra_secrets`, for any other server setting. The execution role gets read access to the extra secrets.
- `ecs_task_role_policy_arns`, for gap analysis of the AWS account.
- `domain_name` and `certificate_arn` are optional. Without them the ALB serves HTTP on its DNS name.
- `alb_internal`, `cpu_architecture`, `database_skip_final_snapshot`, `container_health_check_path`, `container_health_check_start_period`, `container_stop_timeout`, `health_check_grace_period_seconds`, and `secrets_recovery_window_in_days`.
- Outputs `stategraph_url`, `stategraph_secret_arn`, and `ecs_task_definition_arn`.
- `tests/`, run by `tofu test` with a mock AWS provider.
- A Makefile with `check`, `fmt`, `validate`, `lint`, `docs`, and `test` targets.

### Removed

- `container_port`. The image listens on 8080.

## [1.0.0] - 2025-02-09

### Added

- Initial release of Terraform module for deploying Stategraph on AWS ECS
- ECS Fargate cluster and service configuration
- Application Load Balancer with HTTPS/HTTP listeners
- RDS PostgreSQL database (Multi-AZ support)
- Security groups for ALB, ECS tasks, and RDS
- IAM roles for ECS task execution and runtime
- AWS Secrets Manager integration for credentials
- CloudWatch Logs with configurable retention
- Auto Scaling policies based on CPU and memory
- Container Insights enabled by default
- Support for external PostgreSQL databases
- OAuth authentication support (Google, GitHub, OIDC)
- Complete working example with VPC creation
- Comprehensive documentation and README

### Features

- Production-ready defaults (Multi-AZ, autoscaling, backups)
- Development-optimized configuration options
- Cost optimization guidance
- Security best practices (encryption, least privilege IAM)
- Zero-downtime rolling deployments
- Automatic secret rotation support

[Unreleased]: https://github.com/stategraph/terraform-aws-stategraph-ecs/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/stategraph/terraform-aws-stategraph-ecs/releases/tag/v1.0.0
