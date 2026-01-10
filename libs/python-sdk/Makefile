# A.R.C. Common Python SDK - Makefile

.PHONY: help install test lint format clean

help:
	@echo "A.R.C. Common Python SDK - Development Commands"
	@echo ""
	@echo "  make install    - Install dependencies"
	@echo "  make test       - Run unit tests with coverage"
	@echo "  make lint       - Run linters (ruff, mypy)"
	@echo "  make format     - Format code with black and isort"
	@echo "  make clean      - Remove build artifacts and caches"
	@echo ""

install:
	@echo "Installing dependencies..."
	pip install -r requirements.txt
	@echo "✓ Dependencies installed"

test:
	@echo "Running unit tests..."
	pytest -v --cov=arc_common --cov-report=term-missing --cov-report=html
	@echo "✓ Tests complete (see htmlcov/index.html for coverage report)"

test-unit:
	@echo "Running unit tests only (excluding integration tests)..."
	pytest -v -m "not integration" --cov=arc_common --cov-report=term-missing
	@echo "✓ Unit tests complete"

lint:
	@echo "Running linters..."
	ruff arc_common/
	mypy arc_common/
	@echo "✓ Linting complete"

format:
	@echo "Formatting code..."
	black arc_common/ tests/
	isort arc_common/ tests/
	@echo "✓ Code formatted"

clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info
	rm -rf .pytest_cache/
	rm -rf .coverage
	rm -rf htmlcov/
	rm -rf .mypy_cache/
	rm -rf .ruff_cache/
	find . -type d -name __pycache__ -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	@echo "✓ Clean complete"
