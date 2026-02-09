# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/stategraph/terraform-aws-stategraph-ecs/releases/tag/v1.0.0
