# Video Compare Tool

A native desktop application for comparing two videos side-by-side with frame-by-frame control, built with [Wails](https://wails.io/) (Go + Web Technologies).

## Features

- **Side-by-side video playback** - Compare two videos simultaneously
- **Frame-by-frame navigation** - Step through videos one frame at a time
- **Individual controls** - Control each video independently
- **Video synchronization** - Sync both videos to the same position
- **File validation** - Built-in video file format validation
- **Native desktop app** - Cross-platform native application
- **Modern UI** - Clean, responsive interface

## Requirements

- Go 1.23+
- Node.js (for frontend development)
- [Wails CLI](https://wails.io/docs/gettingstarted/installation)

## Installation

1. **Install Wails CLI:**
   ```bash
   go install github.com/wailsapp/wails/v2/cmd/wails@latest
   ```

2. **Clone or download the project**

3. **Install dependencies:**
   ```bash
   make install-deps
   ```

## Usage

### Development Mode
```bash
make dev
```
This starts the development server with hot reload for both Go and frontend changes.

### Build and Run
```bash
make build
make run
```

### Quick Start
```bash
make dev  # Start development server
```

## Project Structure

```
video-compare/
├── app.go              # Go backend logic
├── main.go             # Application entry point
├── frontend/           # Web frontend
│   ├── index.html      # Main HTML interface
│   └── src/            # Frontend source files
├── build/              # Build output
├── Makefile            # Build and development commands
└── wails.json          # Wails configuration
```

## Makefile Commands

- `make dev` - Start development server with hot reload
- `make build` - Build the application
- `make run` - Run the built application
- `make clean` - Clean build artifacts
- `make install-deps` - Install all dependencies
- `make help` - Show all available commands

## Supported Video Formats

The tool uses HTML5 video players, supporting:
- MP4 (H.264)
- WebM
- OGV
- And other HTML5-compatible formats

## Development

### Backend (Go)
- `app.go` contains the main application logic
- Methods can be exposed to the frontend using Wails bindings
- File validation and video info extraction

### Frontend (HTML/JavaScript)
- `frontend/index.html` contains the complete UI
- Vanilla JavaScript for video controls
- Responsive design with modern styling

## Building for Distribution

```bash
make build-clean
```

This creates a native executable for your platform in the `build/` directory.

## Troubleshooting

- **Video not playing**: Ensure the video file is in a supported format
- **Build errors**: Run `make install-deps` to ensure all dependencies are installed
- **Development issues**: Check that Wails CLI is properly installed

## License

MIT
