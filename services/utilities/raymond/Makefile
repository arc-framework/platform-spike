# Raymond Bootstrap Service - Makefile
# ==============================================================================

.PHONY: help build test test-unit test-integration lint fmt run clean docker-build docker-run

# Variables
BINARY_NAME=raymond
MAIN_PATH=./cmd/raymond
DOCKER_IMAGE=arc/raymond
GO_VERSION=1.25

help: ## Display this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the binary
	@echo "Building $(BINARY_NAME)..."
	@CGO_ENABLED=0 go build -ldflags="-w -s -X main.version=1.0.0" -o bin/$(BINARY_NAME) $(MAIN_PATH)
	@echo "Binary built: bin/$(BINARY_NAME)"

test: test-unit ## Run all tests

test-unit: ## Run unit tests
	@echo "Running unit tests..."
	@go test -v -race -coverprofile=coverage.out ./internal/... ./pkg/...
	@go tool cover -html=coverage.out -o coverage.html
	@echo "Coverage report: coverage.html"

test-integration: ## Run integration tests (requires Docker)
	@echo "Running integration tests..."
	@go test -v -tags=integration ./tests/integration/...

lint: ## Run linters
	@echo "Running golangci-lint..."
	@golangci-lint run --timeout=5m

fmt: ## Format code with gofumpt
	@echo "Formatting code..."
	@gofumpt -l -w .
	@echo "Code formatted"

run: ## Run the service locally
	@echo "Starting $(BINARY_NAME)..."
	@go run $(MAIN_PATH)/main.go -config config.example.yaml

clean: ## Clean build artifacts
	@echo "Cleaning..."
	@rm -rf bin/ coverage.out coverage.html
	@echo "Cleaned"

docker-build: ## Build Docker image
	@echo "Building Docker image..."
	@docker build -t $(DOCKER_IMAGE):latest .
	@echo "Docker image built: $(DOCKER_IMAGE):latest"

docker-run: ## Run Docker container
	@echo "Running Docker container..."
	@docker run --rm -p 8081:8081 --name raymond $(DOCKER_IMAGE):latest

mod-tidy: ## Tidy go.mod
	@echo "Tidying go.mod..."
	@go mod tidy
	@echo "go.mod tidied"

mod-download: ## Download dependencies
	@echo "Downloading dependencies..."
	@go mod download
	@echo "Dependencies downloaded"

deps: mod-download ## Install dependencies

.DEFAULT_GOAL := help

