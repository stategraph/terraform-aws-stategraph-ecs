# The provider validates ARN-shaped arguments, so computed ARNs need mock defaults.
mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
      id     = "us-east-1"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/stategraph-production/50dc6c495c0c9188"
      dns_name = "stategraph-production-123456789.us-east-1.elb.amazonaws.com"
      zone_id  = "Z35SXDOTRQ7X7K"
    }
  }

  mock_resource "aws_lb_target_group" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/stategraph-production/73e2d6bc24d8a067"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/stategraph-ecs-production"
    }
  }

  mock_resource "aws_secretsmanager_secret" {
    defaults = {
      arn = "arn:aws:secretsmanager:us-east-1:123456789012:secret:stategraph-production-AbCdEf"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/stategraph-production"
    }
  }

  mock_resource "aws_ecs_cluster" {
    defaults = {
      id  = "arn:aws:ecs:us-east-1:123456789012:cluster/stategraph-production"
      arn = "arn:aws:ecs:us-east-1:123456789012:cluster/stategraph-production"
    }
  }

  mock_resource "aws_ecs_task_definition" {
    defaults = {
      arn = "arn:aws:ecs:us-east-1:123456789012:task-definition/stategraph-production:1"
    }
  }

  mock_resource "aws_db_instance" {
    defaults = {
      address  = "stategraph-production.abcdefghijkl.us-east-1.rds.amazonaws.com"
      endpoint = "stategraph-production.abcdefghijkl.us-east-1.rds.amazonaws.com:5432"
      port     = 5432
    }
  }
}

variables {
  vpc_id             = "vpc-0123456789abcdef0"
  private_subnet_ids = ["subnet-private-a", "subnet-private-b"]
  public_subnet_ids  = ["subnet-public-a", "subnet-public-b"]
}

run "defaults" {
  command = apply

  assert {
    condition     = length(aws_lb_listener.https) == 0
    error_message = "Without a certificate there must be no HTTPS listener."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "forward"
    error_message = "Without a certificate the HTTP listener must forward to the target group."
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.alb_https) == 0
    error_message = "Without a certificate there must be no HTTPS ingress rule."
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.alb_http) == ["0.0.0.0/0"]
    error_message = "The default HTTP ingress rule must be keyed by 0.0.0.0/0."
  }

  assert {
    condition     = output.stategraph_url == "http://${aws_lb.stategraph.dns_name}"
    error_message = "Without domain_name the URL must be the ALB DNS name over HTTP."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].image == "ghcr.io/stategraph/stategraph-server:3.1.0"
    error_message = "The default image must pin the 3.1.0 release."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["STATEGRAPH_UI_BASE"] == output.stategraph_url
    error_message = "STATEGRAPH_UI_BASE must be the console URL."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["STATEGRAPH_OAUTH_REDIRECT_BASE"] == output.stategraph_url
    error_message = "STATEGRAPH_OAUTH_REDIRECT_BASE must equal STATEGRAPH_UI_BASE."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["DB_HOST"] == aws_db_instance.stategraph[0].address
    error_message = "DB_HOST must be the RDS address."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["DB_PORT"] == tostring(aws_db_instance.stategraph[0].port)
    error_message = "DB_PORT must be the port the RDS instance reports."
  }

  assert {
    condition     = aws_vpc_security_group_ingress_rule.rds_from_ecs[0].from_port == aws_db_instance.stategraph[0].port && aws_vpc_security_group_egress_rule.ecs_postgres[0].to_port == aws_db_instance.stategraph[0].port
    error_message = "The RDS security group rules must use the port the RDS instance reports."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["DB_NAME"] == "stategraph"
    error_message = "DB_NAME must be the RDS database name."
  }

  assert {
    condition = length(setintersection(
      toset([for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name]),
      toset(["STATEGRAPH_OAUTH_TYPE", "STATEGRAPH_COST_ENABLED", "STATEGRAPH_SECURITY", "PRICING_DB_HOST"])
    )) == 0
    error_message = "Optional features must be off by default."
  }

  assert {
    condition     = toset([for s in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].secrets : s.name]) == toset(["DB_USER", "DB_PASS", "STATEGRAPH_OAUTH_COOKIE_SECRET"])
    error_message = "The default secrets must be the database credentials and the cookie secret."
  }

  assert {
    condition     = endswith({ for s in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].secrets : s.name => s.valueFrom }["STATEGRAPH_OAUTH_COOKIE_SECRET"], ":cookie_secret::")
    error_message = "The cookie secret must come from the cookie_secret key of the server secret."
  }

  assert {
    condition     = contains(keys(jsondecode(nonsensitive(aws_secretsmanager_secret_version.stategraph.secret_string))), "cookie_secret")
    error_message = "The server secret must hold a cookie secret."
  }

  assert {
    condition     = length(jsondecode(nonsensitive(aws_secretsmanager_secret_version.stategraph.secret_string))["cookie_secret"]) == 32
    error_message = "The generated cookie secret must have 32 characters."
  }

  assert {
    condition     = !contains(keys(jsondecode(nonsensitive(aws_secretsmanager_secret_version.stategraph.secret_string))), "license_key")
    error_message = "Without license_key the server secret must not hold a license_key key."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].healthCheck.command[1] == "curl -f http://localhost:8080/health/live || exit 1"
    error_message = "The container health check must probe /health/live."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].healthCheck.startPeriod == 120
    error_message = "The container health check start period must be 120 seconds."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].stopTimeout == 60
    error_message = "The container stop timeout must be 60 seconds."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].portMappings[0].hostPort == 8080
    error_message = "hostPort must equal the container port."
  }

  assert {
    condition     = aws_lb_target_group.stategraph.health_check[0].path == "/health/ready"
    error_message = "The target group must probe /health/ready."
  }

  assert {
    condition     = aws_ecs_service.stategraph.health_check_grace_period_seconds == 300
    error_message = "The service must have a 300 second health check grace period."
  }

  assert {
    condition     = aws_ecs_task_definition.stategraph.runtime_platform[0].cpu_architecture == "X86_64"
    error_message = "The default CPU architecture must be X86_64."
  }

  assert {
    condition     = aws_db_instance.stategraph[0].engine_version == "17" && aws_db_instance.stategraph[0].auto_minor_version_upgrade == true
    error_message = "RDS must run PostgreSQL 17 with automatic minor upgrades."
  }

  assert {
    condition     = aws_db_instance.stategraph[0].deletion_protection == true && aws_db_instance.stategraph[0].skip_final_snapshot == false
    error_message = "RDS must have deletion protection and a final snapshot by default."
  }

  assert {
    condition     = aws_lb.stategraph.drop_invalid_header_fields == true && aws_lb.stategraph.internal == false
    error_message = "The ALB must drop invalid header fields and be internet-facing by default."
  }
}

run "https_domain" {
  command = apply

  variables {
    domain_name     = "stategraph.example.com"
    certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1 && aws_lb_listener.https[0].certificate_arn == var.certificate_arn
    error_message = "With a certificate there must be one HTTPS listener with that certificate."
  }

  assert {
    condition     = aws_lb_listener.http.default_action[0].type == "redirect" && aws_lb_listener.http.default_action[0].redirect[0].port == "443"
    error_message = "With a certificate the HTTP listener must redirect to HTTPS."
  }

  assert {
    condition     = keys(aws_vpc_security_group_ingress_rule.alb_https) == ["0.0.0.0/0"]
    error_message = "With a certificate there must be an HTTPS ingress rule per CIDR."
  }

  assert {
    condition     = output.stategraph_url == "https://stategraph.example.com"
    error_message = "With a certificate and a domain the URL must be https://<domain_name>."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["STATEGRAPH_UI_BASE"] == "https://stategraph.example.com"
    error_message = "STATEGRAPH_UI_BASE must be the HTTPS URL."
  }
}

run "features" {
  command = apply

  variables {
    domain_name               = "stategraph.example.com"
    certificate_arn           = "arn:aws:acm:us-east-1:123456789012:certificate/0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b"
    license_key               = "license-key-value"
    oauth_enabled             = true
    oauth_provider            = "google"
    oauth_client_id           = "client-id.apps.googleusercontent.com"
    oauth_client_secret       = "client-secret-value"
    oauth_email_domain        = "example.com"
    oauth_display_name        = "Google Workspace"
    cost_enabled              = true
    security_scanning_enabled = true
    extra_environment = [
      { name = "TERRAT_TELEMETRY_LEVEL", value = "disabled" },
    ]
    extra_secrets = [
      { name = "GITHUB_APP_PEM", value_from = "arn:aws:secretsmanager:us-east-1:123456789012:secret:stategraph/github-app-AbCdEf:pem::" },
    ]
  }

  assert {
    condition = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value } == {
      STATEGRAPH_UI_BASE             = "https://stategraph.example.com"
      STATEGRAPH_OAUTH_REDIRECT_BASE = "https://stategraph.example.com"
      DB_HOST                        = aws_db_instance.stategraph[0].address
      DB_PORT                        = "5432"
      DB_NAME                        = "stategraph"
      STATEGRAPH_OAUTH_TYPE          = "google"
      STATEGRAPH_OAUTH_CLIENT_ID     = "client-id.apps.googleusercontent.com"
      STATEGRAPH_OAUTH_EMAIL_DOMAIN  = "example.com"
      STATEGRAPH_OAUTH_DISPLAY_NAME  = "Google Workspace"
      STATEGRAPH_COST_ENABLED        = "true"
      PRICING_DB_HOST                = aws_db_instance.stategraph[0].address
      PRICING_DB_PORT                = "5432"
      PRICING_DB_NAME                = "cloud_pricing"
      PRICING_DB_SSLMODE             = "require"
      STATEGRAPH_SECURITY            = "1"
      TERRAT_TELEMETRY_LEVEL         = "disabled"
    }
    error_message = "The container environment must hold exactly the server variables of the enabled features."
  }

  assert {
    condition = { for s in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].secrets : s.name => s.valueFrom } == {
      DB_USER                        = "${aws_secretsmanager_secret.database.arn}:username::"
      DB_PASS                        = "${aws_secretsmanager_secret.database.arn}:password::"
      STATEGRAPH_OAUTH_COOKIE_SECRET = "${aws_secretsmanager_secret.stategraph.arn}:cookie_secret::"
      STATEGRAPH_LICENSE_KEY         = "${aws_secretsmanager_secret.stategraph.arn}:license_key::"
      STATEGRAPH_OAUTH_CLIENT_SECRET = "${aws_secretsmanager_secret.stategraph.arn}:oauth_client_secret::"
      PRICING_DB_USER                = "${aws_secretsmanager_secret.database.arn}:username::"
      PRICING_DB_PASSWORD            = "${aws_secretsmanager_secret.database.arn}:password::"
      GITHUB_APP_PEM                 = "arn:aws:secretsmanager:us-east-1:123456789012:secret:stategraph/github-app-AbCdEf:pem::"
    }
    error_message = "The container secrets must hold exactly the secrets of the enabled features."
  }

  assert {
    condition     = toset(keys(jsondecode(nonsensitive(aws_secretsmanager_secret_version.stategraph.secret_string)))) == toset(["cookie_secret", "license_key", "oauth_client_secret"])
    error_message = "The server secret must hold the cookie secret, the license key, and the OAuth client secret."
  }

  assert {
    condition     = jsondecode(nonsensitive(aws_secretsmanager_secret_version.stategraph.secret_string))["license_key"] == "license-key-value"
    error_message = "The server secret must hold the license key."
  }

  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.ecs_execution_secrets.policy).Statement[0].Resource, "arn:aws:secretsmanager:us-east-1:123456789012:secret:stategraph/github-app-AbCdEf")
    error_message = "The execution role must read the extra secret, without the json-key suffix."
  }
}

run "oidc" {
  command = apply

  variables {
    oauth_enabled       = true
    oauth_provider      = "oidc"
    oauth_client_id     = "client-id"
    oauth_client_secret = "client-secret-value"
    oauth_issuer_url    = "https://login.example.com"
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["STATEGRAPH_OAUTH_TYPE"] == "oidc"
    error_message = "STATEGRAPH_OAUTH_TYPE must be oidc."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["STATEGRAPH_OAUTH_OIDC_ISSUER_URL"] == "https://login.example.com"
    error_message = "STATEGRAPH_OAUTH_OIDC_ISSUER_URL must be the issuer URL."
  }

  assert {
    condition     = !contains([for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name], "STATEGRAPH_OAUTH_EMAIL_DOMAIN")
    error_message = "Without oauth_email_domain the variable must stay unset."
  }
}

run "external_database" {
  command = apply

  variables {
    create_database            = false
    external_database_host     = "db.internal.example.com"
    external_database_port     = 5433
    external_database_name     = "stategraph"
    external_database_username = "stategraph"
    external_database_password = "external-password"
  }

  assert {
    condition     = length(aws_db_instance.stategraph) == 0 && length(aws_security_group.rds) == 0 && length(aws_db_subnet_group.stategraph) == 0
    error_message = "With an external database the module must create no RDS resources."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["DB_HOST"] == "db.internal.example.com"
    error_message = "DB_HOST must be the external host."
  }

  assert {
    condition     = { for e in jsondecode(aws_ecs_task_definition.stategraph.container_definitions)[0].environment : e.name => e.value }["DB_PORT"] == "5433"
    error_message = "DB_PORT must be the external port."
  }

  assert {
    condition     = length(aws_vpc_security_group_egress_rule.ecs_external_postgres) == 1 && aws_vpc_security_group_egress_rule.ecs_external_postgres[0].from_port == 5433
    error_message = "The tasks must have an egress rule to the external port."
  }

  assert {
    condition     = jsondecode(nonsensitive(aws_secretsmanager_secret_version.database.secret_string))["password"] == "external-password"
    error_message = "The database secret must hold the external password."
  }
}

run "restricted_alb" {
  command = apply

  variables {
    domain_name       = "stategraph.internal.example.com"
    certificate_arn   = "arn:aws:acm:us-east-1:123456789012:certificate/0f1e2d3c-4b5a-6978-8a9b-0c1d2e3f4a5b"
    alb_internal      = true
    alb_ingress_cidrs = ["10.0.0.0/8", "192.168.0.0/16"]
    cpu_architecture  = "ARM64"
  }

  assert {
    condition     = aws_lb.stategraph.internal == true
    error_message = "alb_internal must make the ALB internal."
  }

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.alb_http)) == toset(["10.0.0.0/8", "192.168.0.0/16"])
    error_message = "There must be one HTTP ingress rule per CIDR."
  }

  assert {
    condition     = toset(keys(aws_vpc_security_group_ingress_rule.alb_https)) == toset(["10.0.0.0/8", "192.168.0.0/16"])
    error_message = "There must be one HTTPS ingress rule per CIDR."
  }

  assert {
    condition     = aws_ecs_task_definition.stategraph.runtime_platform[0].cpu_architecture == "ARM64"
    error_message = "cpu_architecture must set the task runtime platform."
  }
}
