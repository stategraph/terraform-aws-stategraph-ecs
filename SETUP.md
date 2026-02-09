# Setting Up the Public Repository

This guide explains how to create and publish the `terraform-aws-stategraph-ecs` public repository.

## Step 1: Create GitHub Repository

1. Go to https://github.com/organizations/stategraph/repositories/new
2. Set repository name: `terraform-aws-stategraph-ecs`
3. Description: `Terraform module for deploying Stategraph on AWS ECS with Fargate`
4. **Visibility: Public** ✅
5. **Do NOT initialize** with README, .gitignore, or license (we already have these)
6. Click "Create repository"

## Step 2: Initialize and Push

```bash
# Copy all files from /tmp/terraform-aws-stategraph-ecs to a clean directory
cd /tmp/terraform-aws-stategraph-ecs

# Initialize git
git init
git add .
git commit -m "Initial release: Terraform module for Stategraph on AWS ECS

- ECS Fargate cluster and service
- Application Load Balancer with HTTPS
- RDS PostgreSQL (Multi-AZ)
- Security groups and IAM roles
- Secrets Manager integration
- Auto Scaling and Container Insights
- Complete examples and documentation"

# Add remote and push
git remote add origin git@github.com:stategraph/terraform-aws-stategraph-ecs.git
git branch -M main
git push -u origin main
```

## Step 3: Create First Release

1. Go to https://github.com/stategraph/terraform-aws-stategraph-ecs/releases/new
2. Click "Choose a tag"
3. Type: `v1.0.0` and click "Create new tag: v1.0.0 on publish"
4. Release title: `v1.0.0 - Initial Release`
5. Description:
   ```markdown
   ## Initial Release

   Terraform module for deploying Stategraph on AWS ECS Fargate.

   ### Features

   - ✅ ECS Fargate cluster and service
   - ✅ Application Load Balancer with HTTPS/HTTP
   - ✅ RDS PostgreSQL (Multi-AZ support)
   - ✅ Security groups (ALB, ECS, RDS)
   - ✅ IAM roles with least privilege
   - ✅ Secrets Manager for credentials
   - ✅ CloudWatch Logs and Container Insights
   - ✅ Auto Scaling (CPU and memory-based)
   - ✅ OAuth authentication support
   - ✅ External PostgreSQL support
   - ✅ Complete working examples

   ### Quick Start

   \`\`\`hcl
   module "stategraph" {
     source  = "stategraph/stategraph-ecs/aws"
     version = "~> 1.0"

     vpc_id             = "vpc-xxxxx"
     private_subnet_ids = ["subnet-xxxxx", "subnet-yyyyy"]
     public_subnet_ids  = ["subnet-aaaaa", "subnet-bbbbb"]
     domain_name        = "stategraph.example.com"
     certificate_arn    = "arn:aws:acm:..."
   }
   \`\`\`

   ### Documentation

   - [Module README](https://github.com/stategraph/terraform-aws-stategraph-ecs/blob/main/README.md)
   - [Complete Example](https://github.com/stategraph/terraform-aws-stategraph-ecs/tree/main/examples/complete)
   - [Stategraph Docs](https://stategraph.com/docs/quickstart/ecs)
   ```
6. Click "Publish release"

## Step 4: Publish to Terraform Registry

1. Go to https://registry.terraform.io/
2. Sign in with GitHub (if not already signed in)
3. Click "Publish" → "Module"
4. Select repository: `stategraph/terraform-aws-stategraph-ecs`
5. The registry will automatically:
   - Detect it's a Terraform module
   - Read version from git tags
   - Generate documentation from README
   - Create the module page

The module will be available at:
```
https://registry.terraform.io/modules/stategraph/stategraph-ecs/aws
```

Users can then use:
```hcl
module "stategraph" {
  source  = "stategraph/stategraph-ecs/aws"
  version = "~> 1.0"
  # ...
}
```

## Step 5: Configure Repository Settings

### Branch Protection

1. Go to Settings → Branches
2. Add rule for `main` branch:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
   - Select: `Validate Terraform`, `TFLint`, `Documentation`
   - ✅ Require branches to be up to date before merging
   - ✅ Require linear history

### GitHub Actions Permissions

1. Go to Settings → Actions → General
2. Workflow permissions: Select "Read and write permissions"
3. ✅ Allow GitHub Actions to create and approve pull requests

### Topics

1. Go to repository homepage
2. Click ⚙️ (gear icon) next to "About"
3. Add topics:
   - `terraform`
   - `terraform-module`
   - `aws`
   - `ecs`
   - `fargate`
   - `stategraph`
   - `infrastructure-as-code`
   - `terraform-aws`

### Description and Website

1. In "About" section:
   - Description: `Terraform module for deploying Stategraph on AWS ECS with Fargate`
   - Website: `https://stategraph.com/docs/quickstart/ecs`

## Step 6: Verify Everything Works

### Test Registry Installation

```bash
mkdir test-module && cd test-module

cat > main.tf <<EOF
module "stategraph" {
  source  = "stategraph/stategraph-ecs/aws"
  version = "~> 1.0"

  vpc_id             = "vpc-xxxxx"
  private_subnet_ids = ["subnet-xxxxx"]
  public_subnet_ids  = ["subnet-aaaaa"]
  domain_name        = "test.example.com"
  certificate_arn    = "arn:aws:acm:..."
}
EOF

terraform init
# Should download from registry successfully
```

### Verify Registry Page

1. Visit https://registry.terraform.io/modules/stategraph/stategraph-ecs/aws
2. Check that:
   - ✅ README displays correctly
   - ✅ Inputs/Outputs are documented
   - ✅ Examples are visible
   - ✅ Version shows v1.0.0
   - ✅ Source links to GitHub

## Step 7: Update Documentation Links

The main Stategraph documentation at `stategraph.com/docs/quickstart/ecs` should already reference the new repository location. Verify:

1. Visit https://stategraph.com/docs/quickstart/ecs
2. Check that module source shows: `stategraph/stategraph-ecs/aws`
3. Check that links point to `github.com/stategraph/terraform-aws-stategraph-ecs`

## Step 8: Announce Release

1. **Blog Post** (optional): Announce the new module on the Stategraph blog
2. **Slack Community**: Share in #announcements channel
3. **Twitter/Social**: Tweet about the release
4. **Documentation**: Ensure docs.stategraph.com is updated

## Maintenance

### Releasing New Versions

1. Make changes, commit, and push to main (via PR)
2. Update CHANGELOG.md
3. Create new tag: `git tag v1.1.0 && git push --tags`
4. Create GitHub release from tag
5. Terraform Registry automatically picks up new version

### Module Updates

All future updates should:
1. Be made via Pull Request
2. Pass CI checks (validation, lint, docs)
3. Update CHANGELOG.md
4. Follow semantic versioning
5. Include example updates if needed

## Troubleshooting

### Registry Not Detecting Module

- Ensure repository is public
- Check that module is in repository root (not subdirectory)
- Verify git tag exists: `git tag -l`
- Wait 5-10 minutes for registry sync

### CI Checks Failing

- Run locally: `terraform fmt -check -recursive`
- Run locally: `terraform validate`
- Check GitHub Actions logs for details

### Documentation Not Updating

- Ensure README.md is in repository root
- Use terraform-docs to regenerate: `terraform-docs markdown table . > README.md`
- Commit and push changes

## Security

### Repository Secrets

Add these secrets in Settings → Secrets and variables → Actions:

- None required for public module
- If you add testing that requires AWS access, add `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

### Dependabot

Consider enabling Dependabot for Terraform provider updates:

1. Create `.github/dependabot.yml`:
   ```yaml
   version: 2
   updates:
     - package-ecosystem: "terraform"
       directory: "/"
       schedule:
         interval: "weekly"
   ```

## Complete! 🎉

Your Terraform module is now:
- ✅ Published on GitHub
- ✅ Available on Terraform Registry
- ✅ Documented on stategraph.com
- ✅ Ready for community use
