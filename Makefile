.PHONY: lint format install-hooks

PYTHON_FILES := scripts
SHELL_FILES := on_policy_distillation.sh grpo.sh

lint:
	uvx ruff check $(PYTHON_FILES)
	uvx ruff format --check $(PYTHON_FILES)
	uvx shellcheck-py $(SHELL_FILES)

format:
	uvx ruff check --fix $(PYTHON_FILES)
	uvx ruff format $(PYTHON_FILES)

install-hooks:
	pre-commit install
