# Multi-stage Dockerfile for video-compare-native-gui
# Build stage
FROM golang:1.23.0-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    gcc \
    musl-dev \
    pkgconfig \
    libc6-compat \
    libx11-dev \
    libxrandr-dev \
    libxinerama-dev \
    libxcursor-dev \
    libxi-dev \
    mesa-dev \
    alsa-lib-dev \
    pulseaudio-dev \
    vlc-dev

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags "-s -w" -o video-compare-native-gui .

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    libx11 \
    libxrandr \
    libxinerama \
    libxcursor \
    libxi \
    mesa \
    alsa-lib \
    pulseaudio \
    vlc \
    ttf-dejavu \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -s /bin/sh -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy binary from builder stage
COPY --from=builder /app/video-compare-native-gui .

# Change ownership to non-root user
RUN chown appuser:appuser /app/video-compare-native-gui

# Switch to non-root user
USER appuser

# Expose any necessary ports (if needed in the future)
# EXPOSE 8080

# Set environment variables
ENV DISPLAY=:0
ENV VLC_PLUGIN_PATH=/usr/lib/vlc/plugins

# Run the application
ENTRYPOINT ["./video-compare-native-gui"]
