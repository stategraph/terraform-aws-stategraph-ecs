# Contributing to terraform-aws-stategraph-ecs

Thank you for your interest in contributing to the Stategraph ECS Terraform module!

## Development Setup

1. **Prerequisites**
   - Terraform 1.0+
   - AWS CLI configured
   - Git

2. **Clone the repository**
   ```bash
   git clone https://github.com/stategraph/terraform-aws-stategraph-ecs.git
   cd terraform-aws-stategraph-ecs
   ```

3. **Install development tools**
   ```bash
   # TFLint
   curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

   # terraform-docs
   go install github.com/terraform-docs/terraform-docs@latest
   ```

## Making Changes

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow Terraform best practices
   - Update documentation
   - Add examples if introducing new features

3. **Format and validate**
   ```bash
   # Format code
   terraform fmt -recursive

   # Validate
   terraform init -backend=false
   terraform validate

   # Run TFLint
   tflint --recursive
   ```

4. **Update documentation**
   ```bash
   # Generate documentation
   terraform-docs markdown table . > README.md
   ```

5. **Test your changes**
   - Test in a real AWS account if possible
   - Verify examples work
   - Check that outputs are correct

## Pull Request Process

1. **Update CHANGELOG.md**
   - Add your changes under `[Unreleased]`
   - Follow [Keep a Changelog](https://keepachangelog.com/) format

2. **Submit PR**
   - Provide clear description of changes
   - Reference any related issues
   - Ensure CI checks pass

3. **Code Review**
   - Address reviewer feedback
   - Make requested changes

## Coding Standards

### Terraform Style

- Use 2 spaces for indentation
- Use snake_case for resource names and variables
- Add descriptions to all variables and outputs
- Use meaningful resource names
- Group related resources together

### Documentation

- Document all variables with:
  - Clear description
  - Type
  - Default value (if applicable)
  - Example usage
- Document all outputs
- Update examples when adding features
- Keep README.md up to date

### Examples

- Provide working examples
- Use realistic variable values
- Include comments explaining key decisions
- Test examples before submitting

## Versioning

This module follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: Backward-compatible functionality additions
- **PATCH**: Backward-compatible bug fixes

## Release Process

Releases are managed by maintainers:

1. Update CHANGELOG.md
2. Update version references in examples
3. Create Git tag
4. Publish to Terraform Registry (automated)

## Questions?

- Open an issue for bugs or feature requests
- Join our [Slack community](https://stategraph.com/slack)
- Email: support@stategraph.com

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
