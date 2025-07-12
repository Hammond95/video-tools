package main

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
)

// App struct
type App struct {
	ctx context.Context
}

// NewApp creates a new App application struct
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts. The context is saved
// so we can call the runtime methods
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

// GetVideoInfo returns information about a video file
func (a *App) GetVideoInfo(filePath string) map[string]interface{} {
	info := make(map[string]interface{})

	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		info["error"] = "File not found"
		return info
	}

	// Get basic file info
	fileInfo, err := os.Stat(filePath)
	if err != nil {
		info["error"] = fmt.Sprintf("Error reading file: %v", err)
		return info
	}

	info["name"] = filepath.Base(filePath)
	info["path"] = filePath
	info["size"] = fileInfo.Size()
	info["modified"] = fileInfo.ModTime()

	return info
}

// ValidateVideoFile checks if a file is a valid video file
func (a *App) ValidateVideoFile(filePath string) bool {
	// Check if file exists
	if _, err := os.Stat(filePath); os.IsNotExist(err) {
		return false
	}

	// Check file extension
	ext := filepath.Ext(filePath)
	validExtensions := []string{".mp4", ".avi", ".mkv", ".mov", ".wmv", ".flv", ".webm", ".m4v"}

	for _, validExt := range validExtensions {
		if ext == validExt {
			return true
		}
	}

	return false
}
