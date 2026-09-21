.PHONY: help lint test validate

SHELL_SCRIPTS := $(wildcard scripts/*.sh) $(wildcard sample-app/ci/*.sh)

help:
	@printf '%s\n' \
	  'make lint      Check shell syntax and Terraform formatting' \
	  'make test      Run sample application tests' \
	  'make validate  Run all local validation'

lint:
	@for script in $(SHELL_SCRIPTS); do bash -n "$$script"; done
	@terraform -chdir=terraform fmt -check -recursive

test:
	@cd sample-app && npm test

validate: lint test
