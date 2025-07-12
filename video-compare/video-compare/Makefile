# Video Compare Tool Makefile (Wails)

BINARY_NAME=video-compare
WAILS_PATH=/Users/martin.deluca/.asdf/installs/golang/1.23.0/packages/bin/wails
BUILD_PATH=./build/bin/video-compare.app/Contents/MacOS/video-compare

.PHONY: all
all: build

.PHONY: dev
dev:
	@echo "Starting development server..."
	$(WAILS_PATH) dev

.PHONY: build
build:
	@echo "Building application..."
	$(WAILS_PATH) build

.PHONY: build-clean
build-clean:
	@echo "Building clean application..."
	$(WAILS_PATH) build -clean

.PHONY: run
run:
	@echo "Running application..."
	$(BUILD_PATH)

.PHONY: clean
clean:
	@echo "Cleaning build artifacts..."
	rm -rf build/
	rm -f $(BINARY_NAME)

.PHONY: frontend-dev
frontend-dev:
	@echo "Starting frontend development server..."
	cd frontend && npm run dev

.PHONY: frontend-build
frontend-build:
	@echo "Building frontend..."
	cd frontend && npm run build

.PHONY: install-deps
install-deps:
	@echo "Installing dependencies..."
	cd frontend && npm install
	go mod tidy

.PHONY: help
help:
	@echo "Available targets:"
	@echo "  dev           - Start development server with hot reload"
	@echo "  build         - Build the application"
	@echo "  build-clean   - Build with clean cache"
	@echo "  run           - Run the built application"
	@echo "  clean         - Remove build artifacts"
	@echo "  frontend-dev  - Start frontend development server"
	@echo "  frontend-build- Build frontend assets"
	@echo "  install-deps  - Install all dependencies"
	@echo "  help          - Show this help" 