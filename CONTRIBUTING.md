# Contributing to terraform-aws-stategraph-ecs

Thank you for your interest in contributing to the Stategraph ECS Terraform module!

## Development setup

1. **Tools**
   - [OpenTofu](https://opentofu.org/docs/intro/install/) 1.6 or later, or Terraform 1.7 or later
   - [TFLint](https://github.com/terraform-linters/tflint)
   - [terraform-docs](https://terraform-docs.io/user-guide/installation/)
   - AWS CLI, for changes you test against an account

2. **Clone the repository**
   ```bash
   git clone https://github.com/stategraph/terraform-aws-stategraph-ecs.git
   cd terraform-aws-stategraph-ecs
   ```

3. **Run the checks**
   ```bash
   make check
   ```

   `make check` runs, in order:

   | Target | What it does |
   |--------|--------------|
   | `fmt-check` | `tofu fmt -check -recursive` |
   | `validate` | `tofu init` and `tofu validate` on the module and each example |
   | `lint` | `tflint --recursive` |
   | `docs-check` | Checks that the reference in README.md matches the variables and outputs |
   | `test` | `tofu test`, with a mock AWS provider. No credentials needed |

   Set `TOFU=terraform` to run the checks with Terraform.

## Making changes

1. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow Terraform best practices
   - Add a test in `tests/` for a new variable or a changed container setting
   - Update the example when you add a feature

3. **Format and regenerate the docs**
   ```bash
   make fmt
   make docs
   ```

4. **Run the checks**
   ```bash
   make check
   ```

5. **Test against AWS when the change touches resources**
   - Apply `examples/complete` in a test account
   - Check `/health/live` and `/health/ready` on the URL from `terraform output stategraph_url`
   - Destroy when done

## Pull request process

1. **Update CHANGELOG.md**
   - Add your changes under `[Unreleased]`
   - Follow the [Keep a Changelog](https://keepachangelog.com/) format

2. **Submit the PR**
   - Describe the change and reference related issues
   - CI runs `make check`

3. **Code review**
   - Address reviewer feedback

## Coding standards

### Terraform style

- 2 spaces for indentation
- snake_case for resource names and variables
- A description on every variable and output
- Group related resources together

### Documentation

- README.md holds the guide. The reference section between the terraform-docs markers is generated: run `make docs`
- Update the example when you add a feature

### Tests

- `tests/module.tftest.hcl` applies the module with a mock AWS provider and checks the resources it renders
- Add a `run` block for a new feature, or an `assert` to an existing one

## Versioning

This module follows [Semantic Versioning](https://semver.org/):

- **MAJOR**: incompatible changes to variables, defaults, or the server contract
- **MINOR**: backward-compatible additions
- **PATCH**: backward-compatible fixes

## Release process

Releases are managed by maintainers:

1. Move the `[Unreleased]` entries in CHANGELOG.md under the new version
2. Update the `ref` in the README and example module blocks
3. Create the Git tag

## Questions?

- Open an issue for bugs or feature requests
- Documentation: https://stategraph.com/docs/admin/self-hosting/ecs

## License

By contributing, you agree that your contributions will be licensed under the Apache License 2.0.
