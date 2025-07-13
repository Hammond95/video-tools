# Makefile for video-compare-native-gui
# A portable video comparison tool with native GUI

# Variables
BINARY_NAME=video-compare-native-gui
DOCKER_IMAGE=video-compare-native-gui
DOCKER_TAG=latest
GO_VERSION=1.23.0

# Host user/group for Docker volume permissions
HOST_USER := $(shell id -u)
HOST_GROUP := $(shell id -g)

# Docker resource limits
MAX_CPUS := $(shell docker system info --format='{{json .}}' | jq '.NCPU' 2>/dev/null || echo "2")
MAX_MEM := $(shell docker system info --format='{{json .}}' | jq '.MemTotal' 2>/dev/null || echo "2g")

# Build flags
LDFLAGS=-ldflags "-s -w"
CGO_ENABLED=1

# Default target
.PHONY: all
all: build

# Build the application
.PHONY: build
build:
	@echo "Building $(BINARY_NAME)..."
	CGO_ENABLED=$(CGO_ENABLED) go build $(LDFLAGS) -o $(BINARY_NAME) .

# Build for different platforms
.PHONY: build-linux
build-linux:
	@echo "Building for Linux..."
	GOOS=linux GOARCH=amd64 CGO_ENABLED=$(CGO_ENABLED) go build $(LDFLAGS) -o $(BINARY_NAME)-linux-amd64 .

.PHONY: build-darwin
build-darwin:
	@echo "Building for macOS..."
	GOOS=darwin GOARCH=amd64 CGO_ENABLED=$(CGO_ENABLED) go build $(LDFLAGS) -o $(BINARY_NAME)-darwin-amd64 .

.PHONY: build-windows
build-windows:
	@echo "Building for Windows..."
	GOOS=windows GOARCH=amd64 CGO_ENABLED=$(CGO_ENABLED) go build $(LDFLAGS) -o $(BINARY_NAME)-windows-amd64.exe .

# Build all platforms
.PHONY: build-all
build-all: build-linux build-darwin build-windows

# Run the application
.PHONY: run
run:
	@echo "Running $(BINARY_NAME)..."
	go run .

# Test the application using Docker
.PHONY: test
test: build-dev-tools
	@echo "Running tests..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		--cpus=$(MAX_CPUS) \
		--memory=$(MAX_MEM) \
		$(DOCKER_IMAGE)-dev-tools \
		go test -v -timeout=15m -parallel=4 ./...

# Run tests with coverage using Docker
.PHONY: test-coverage
test-coverage: build-dev-tools
	@echo "Running tests with coverage..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		-e HOST_USER=$(HOST_USER) \
		-e HOST_GROUP=$(HOST_GROUP) \
		--cpus=$(MAX_CPUS) \
		--memory=$(MAX_MEM) \
		$(DOCKER_IMAGE)-dev-tools \
		bash -c "go test -v -timeout=15m -parallel=4 -coverprofile=coverage.out ./... && go tool cover -html=coverage.out -o coverage.html && chown -R $(HOST_USER):$(HOST_GROUP) coverage.*"
	@echo "Coverage report generated: coverage.html"

# Build development tools image
.PHONY: build-dev-tools
build-dev-tools:
	@echo "Building development tools image..."
	docker build -f Dockerfile.dev-tools . -t $(DOCKER_IMAGE)-dev-tools

# Lint the code using Docker
.PHONY: lint
lint: build-dev-tools
	@echo "Running staticcheck..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		--cpus=$(MAX_CPUS) \
		--memory=$(MAX_MEM) \
		$(DOCKER_IMAGE)-dev-tools \
		staticcheck ./...

# Run golangci-lint
.PHONY: lint-golangci
lint-golangci: build-dev-tools
	@echo "Running golangci-lint..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		--cpus=$(MAX_CPUS) \
		--memory=$(MAX_MEM) \
		$(DOCKER_IMAGE)-dev-tools \
		golangci-lint run

# Run gosec security scanner
.PHONY: security
security: build-dev-tools
	@echo "Running security scan..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		--cpus=$(MAX_CPUS) \
		--memory=$(MAX_MEM) \
		$(DOCKER_IMAGE)-dev-tools \
		gosec ./...

# Run cyclomatic complexity check
.PHONY: complexity
complexity: build-dev-tools
	@echo "Running cyclomatic complexity check..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		--cpus=$(MAX_CPUS) \
		--memory=$(MAX_MEM) \
		$(DOCKER_IMAGE)-dev-tools \
		gocyclo -over 15 .

# Format the code using Docker
.PHONY: fmt
fmt: build-dev-tools
	@echo "Formatting code..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		-e HOST_USER=$(HOST_USER) \
		-e HOST_GROUP=$(HOST_GROUP) \
		$(DOCKER_IMAGE)-dev-tools \
		bash -c "go fmt ./... && goimports -w . && chown -R $(HOST_USER):$(HOST_GROUP) ."

# Vet the code using Docker
.PHONY: vet
vet: build-dev-tools
	@echo "Vetting code..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		$(DOCKER_IMAGE)-dev-tools \
		go vet ./...

# Run golint using Docker
.PHONY: golint
golint: build-dev-tools
	@echo "Running golint..."
	docker run \
		--rm \
		-v $(PWD):/app:Z \
		-w /app \
		$(DOCKER_IMAGE)-dev-tools \
		bash -c 'go list ./... | xargs -P4 -L1 golint -set_exit_status'

# Check code quality (comprehensive)
.PHONY: check
check: fmt vet lint golint security complexity

# Install dependencies
.PHONY: deps
deps:
	@echo "Installing dependencies..."
	go mod download
	go mod tidy

# Update dependencies
.PHONY: deps-update
deps-update:
	@echo "Updating dependencies..."
	go get -u ./...
	go mod tidy

# Clean build artifacts
.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(BINARY_NAME)
	rm -f $(BINARY_NAME)-*
	rm -f coverage.out
	rm -f coverage.html

# Docker targets
.PHONY: docker-build
docker-build:
	@echo "Building Docker image..."
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

.PHONY: docker-run
docker-run:
	@echo "Running Docker container..."
	docker run --rm -it \
		-e DISPLAY=$$DISPLAY \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v $$HOME:/home/user \
		$(DOCKER_IMAGE):$(DOCKER_TAG)

.PHONY: docker-push
docker-push:
	@echo "Pushing Docker image..."
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

# Development targets
.PHONY: dev
dev:
	@echo "Starting development mode..."
	@if command -v air >/dev/null 2>&1; then \
		air; \
	else \
		echo "air not found, installing..."; \
		go install github.com/cosmtrek/air@latest; \
		air; \
	fi

# Install development tools locally (alternative to Docker)
.PHONY: install-tools
install-tools:
	@echo "Installing development tools locally..."
	go install honnef.co/go/tools/cmd/staticcheck@latest
	go install github.com/cosmtrek/air@latest
	go install golang.org/x/tools/cmd/goimports@latest
	go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	go install golang.org/x/lint/golint@latest
	go install github.com/fzipp/gocyclo/cmd/gocyclo@latest
	go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest

# Show help
.PHONY: help
help:
	@echo "Available targets:"
	@echo ""
	@echo "Build targets:"
	@echo "  build          - Build the application"
	@echo "  build-linux    - Build for Linux"
	@echo "  build-darwin   - Build for macOS"
	@echo "  build-windows  - Build for Windows"
	@echo "  build-all      - Build for all platforms"
	@echo ""
	@echo "Development targets:"
	@echo "  run            - Run the application"
	@echo "  dev            - Start development mode with hot-reload"
	@echo "  test           - Run tests"
	@echo "  test-coverage  - Run tests with coverage report"
	@echo ""
	@echo "Code quality targets:"
	@echo "  check          - Run comprehensive code quality checks"
	@echo "  fmt            - Format code with gofmt and goimports"
	@echo "  vet            - Vet code"
	@echo "  lint           - Run staticcheck"
	@echo "  lint-golangci  - Run golangci-lint"
	@echo "  golint         - Run golint"
	@echo "  security       - Run security scan with gosec"
	@echo "  complexity     - Check cyclomatic complexity"
	@echo ""
	@echo "Docker targets:"
	@echo "  build-dev-tools - Build development tools Docker image"
	@echo "  docker-build   - Build production Docker image"
	@echo "  docker-run     - Run Docker container"
	@echo "  docker-push    - Push Docker image"
	@echo ""
	@echo "Dependency management:"
	@echo "  deps           - Install dependencies"
	@echo "  deps-update    - Update dependencies"
	@echo "  install-tools  - Install development tools locally"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean          - Clean build artifacts"
	@echo "  help           - Show this help" 