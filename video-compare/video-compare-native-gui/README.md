# Video Compare Native GUI

A portable video comparison tool with native GUI built in Go using Fyne and libVLC for video playback.

## Features

- **Side-by-side video comparison** with synchronized playback
- **Native GUI** using Fyne framework
- **Multiple video format support** (MP4, MKV, AVI, MOV, WebM)
- **Portable** - runs in Docker containers
- **Cross-platform** - builds for Linux, macOS, and Windows

## Prerequisites

### For Local Development
- Go 1.23.0 or later
- VLC media player
- X11 (for Linux GUI support)

### For Docker
- Docker and Docker Compose
- X11 forwarding support (for GUI in containers)

## Quick Start

### Using Docker (Recommended)

1. **Build and run with Docker Compose:**
   ```bash
   # Build and run the application
   docker-compose up --build
   
   # Or run in background
   docker-compose up -d --build
   ```

2. **Using Makefile with Docker:**
   ```bash
   # Build Docker image
   make docker-build
   
   # Run Docker container
   make docker-run
   ```

### Local Development

1. **Install dependencies:**
   ```bash
   make deps
   ```

2. **Build the application:**
   ```bash
   make build
   ```

3. **Run the application:**
   ```bash
   make run
   ```

## Development

### Available Makefile Targets

```bash
# Build targets
make build          # Build for current platform
make build-linux    # Build for Linux
make build-darwin   # Build for macOS
make build-windows  # Build for Windows
make build-all      # Build for all platforms

# Development targets
make run            # Run the application
make dev            # Start development mode with hot-reload
make test           # Run tests
make test-coverage  # Run tests with coverage report
make lint           # Run static analysis
make fmt            # Format code
make vet            # Vet code
make check          # Run fmt, vet, and lint

# Dependency management
make deps           # Install dependencies
make deps-update    # Update dependencies

# Docker targets
make docker-build   # Build Docker image
make docker-run     # Run Docker container
make docker-push    # Push Docker image

# Utility targets
make clean          # Clean build artifacts
make install-tools  # Install development tools
make help           # Show all available targets
```

### Development Mode

For hot-reload development:

```bash
# Start development mode
make dev

# Or using Docker Compose
docker-compose --profile dev up --build
```

### Code Quality

```bash
# Run all code quality checks
make check

# Run specific checks
make fmt    # Format code
make vet    # Vet code
make lint   # Static analysis
```

## Docker Setup

### Production Image

The main Dockerfile creates a multi-stage build with:
- Alpine Linux base for small image size
- All necessary runtime dependencies
- Non-root user for security
- Optimized binary

### Development Image

The development Dockerfile includes:
- All build and development tools
- Hot-reload support with Air
- Source code mounting for live development

### Running with Docker

```bash
# Build and run production image
docker-compose up --build

# Build and run development image
docker-compose --profile dev up --build

# Run with custom video directory
docker run --rm -it \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v $HOME:/home/user \
  -v /path/to/videos:/videos:ro \
  video-compare-native-gui:latest
```

## Project Structure

```
video-compare-native-gui/
├── main.go              # Main application entry point
├── go.mod               # Go module definition
├── go.sum               # Go module checksums
├── Makefile             # Build and development commands
├── Dockerfile           # Production Docker image
├── Dockerfile.dev       # Development Docker image
├── docker-compose.yml   # Docker Compose configuration
├── .dockerignore        # Docker build exclusions
├── .air.toml           # Hot-reload configuration
└── README.md           # This file
```

## Building for Different Platforms

### Cross-compilation

```bash
# Build for specific platforms
make build-linux    # Linux AMD64
make build-darwin   # macOS AMD64
make build-windows  # Windows AMD64

# Build for all platforms
make build-all
```

### Platform-specific Notes

- **Linux**: Requires X11 and VLC libraries
- **macOS**: May require additional setup for VLC
- **Windows**: May require additional DLLs for VLC

## Troubleshooting

### GUI Issues in Docker

If the GUI doesn't appear in Docker:

1. **Check X11 forwarding:**
   ```bash
   xhost +local:docker
   ```

2. **Verify DISPLAY variable:**
   ```bash
   echo $DISPLAY
   ```

3. **Check X11 socket:**
   ```bash
   ls -la /tmp/.X11-unix/
   ```

### VLC Issues

If VLC playback doesn't work:

1. **Check VLC installation:**
   ```bash
   vlc --version
   ```

2. **Set VLC plugin path:**
   ```bash
   export VLC_PLUGIN_PATH=/usr/lib/vlc/plugins
   ```

3. **Verify video file permissions:**
   ```bash
   ls -la /path/to/video/file
   ```

### Build Issues

If you encounter build issues:

1. **Clean and rebuild:**
   ```bash
   make clean
   make deps
   make build
   ```

2. **Update dependencies:**
   ```bash
   make deps-update
   ```

3. **Check Go version:**
   ```bash
   go version
   ```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run code quality checks: `make check`
5. Run tests: `make test`
6. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details. 