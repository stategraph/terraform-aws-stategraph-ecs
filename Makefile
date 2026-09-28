TOFU           ?= tofu
TFLINT         ?= tflint
TERRAFORM_DOCS ?= terraform-docs

EXAMPLES := $(wildcard examples/*/)

.PHONY: check fmt fmt-check init validate lint docs docs-check test clean

check: fmt-check validate lint docs-check test

fmt:
	$(TOFU) fmt -recursive

fmt-check:
	$(TOFU) fmt -check -recursive

init:
	$(TOFU) init -backend=false -input=false
	@for d in $(EXAMPLES); do (cd "$$d" && $(TOFU) init -backend=false -input=false) || exit 1; done

validate: init
	$(TOFU) validate
	@for d in $(EXAMPLES); do (cd "$$d" && $(TOFU) validate) || exit 1; done

lint:
	$(TFLINT) --init
	$(TFLINT) --recursive

docs:
	$(TERRAFORM_DOCS) markdown table --lockfile=false --output-file README.md --output-mode inject .

docs-check:
	$(TERRAFORM_DOCS) markdown table --lockfile=false --output-file README.md --output-mode inject --output-check .

test: init
	$(TOFU) test

clean:
	rm -rf .terraform .terraform.lock.hcl examples/*/.terraform examples/*/.terraform.lock.hcl
