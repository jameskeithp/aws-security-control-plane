TF_DIR     := terraform/environments/dev
LAMBDA_DIR := lambda/remediation

.PHONY: init fmt validate plan apply destroy test lint package clean

init: ## Initialize the dev Terraform working directory
	cd $(TF_DIR) && terraform init

fmt: ## Format all Terraform files
	terraform fmt -recursive terraform

validate: ## Validate the dev Terraform configuration
	cd $(TF_DIR) && terraform validate

plan: ## Show the Terraform execution plan for dev
	cd $(TF_DIR) && terraform plan -out=tfplan

apply: ## Apply a previously created plan for dev
	cd $(TF_DIR) && terraform apply tfplan

destroy: ## Destroy the dev environment (asks for confirmation)
	bash scripts/destroy.sh

test: ## Run the Python test suites
	python3 -m pytest $(LAMBDA_DIR)/tests tests -v

lint: ## Syntax-check Python and shell scripts
	python3 -m compileall -q lambda tests
	bash -n scripts/bootstrap.sh && bash -n scripts/validate.sh && bash -n scripts/destroy.sh
	@echo "lint OK"

package: ## Build the Lambda deployment zip (handler.py only)
	cd $(LAMBDA_DIR) && zip -j remediation.zip handler.py

clean: ## Remove caches and build artifacts
	find . -name "__pycache__" -type d -prune -exec rm -rf {} + 2>/dev/null; true
	find . -name ".pytest_cache" -type d -prune -exec rm -rf {} + 2>/dev/null; true
	rm -f $(LAMBDA_DIR)/remediation.zip
