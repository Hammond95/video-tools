package main

import (
	"fmt"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/visualfc/atk/tk"
)

type VideoPlayer struct {
	mediaPlayer *tk.MediaPlayer
	videoWidget *tk.VideoWidget
	path        string
	title       string

	// UI elements
	fileLabel   *tk.Label
	timeLabel   *tk.Label
	statsLabel  *tk.Label
	progressBar *tk.Scale

	// State
	isPlaying   bool
	currentTime float64
	duration    float64
	fps         float64
	width       int
	height      int
	bitrate     int
}

type VideoCompareApp struct {
	leftPlayer  *VideoPlayer
	rightPlayer *VideoPlayer

	// Common controls
	syncBtn     *tk.Button
	playAllBtn  *tk.Button
	pauseAllBtn *tk.Button
	stopAllBtn  *tk.Button

	// Frame controls
	prevFrameBtn *tk.Button
	nextFrameBtn *tk.Button

	// Stats display
	statsDisplay *tk.Text

	window *tk.Window
}

func main() {
	tk.Init()

	window := tk.NewWindow()
	window.SetTitle("Video Compare - Qt-based Side-by-Side Comparison")
	window.ResizeN(1600, 1000)
	window.CenterWindow()

	app := &VideoCompareApp{
		window: window,
	}

	app.initializePlayers()
	app.createUI()
	app.setupEventHandlers()

	window.Show()
	tk.MainLoop()
}

func (app *VideoCompareApp) initializePlayers() {
	app.leftPlayer = newVideoPlayer("Left Video")
	app.rightPlayer = newVideoPlayer("Right Video")
}

func newVideoPlayer(title string) *VideoPlayer {
	mediaPlayer := tk.NewMediaPlayer()
	videoWidget := tk.NewVideoWidget()

	return &VideoPlayer{
		mediaPlayer: mediaPlayer,
		videoWidget: videoWidget,
		title:       title,
		fileLabel:   tk.NewLabel("No file selected"),
		timeLabel:   tk.NewLabel("00:00 / 00:00"),
		statsLabel:  tk.NewLabel("No video loaded"),
		progressBar: tk.NewScale(),
	}
}

func (app *VideoCompareApp) createUI() {
	// Create file selection buttons
	leftFileBtn := tk.NewButton("Choose Left Video")
	leftFileBtn.OnCommand(func() {
		app.selectVideoFile(app.leftPlayer)
	})

	rightFileBtn := tk.NewButton("Choose Right Video")
	rightFileBtn.OnCommand(func() {
		app.selectVideoFile(app.rightPlayer)
	})

	// Individual player controls
	leftControls := app.createPlayerControls(app.leftPlayer, "Left")
	rightControls := app.createPlayerControls(app.rightPlayer, "Right")

	// Common controls
	app.syncBtn = tk.NewButton("Sync Videos")
	app.syncBtn.OnCommand(app.syncVideos)

	app.playAllBtn = tk.NewButton("Play All")
	app.playAllBtn.OnCommand(app.playAll)

	app.pauseAllBtn = tk.NewButton("Pause All")
	app.pauseAllBtn.OnCommand(app.pauseAll)

	app.stopAllBtn = tk.NewButton("Stop All")
	app.stopAllBtn.OnCommand(app.stopAll)

	// Frame controls
	app.prevFrameBtn = tk.NewButton("Previous Frame")
	app.prevFrameBtn.OnCommand(app.previousFrame)

	app.nextFrameBtn = tk.NewButton("Next Frame")
	app.nextFrameBtn.OnCommand(app.nextFrame)

	// Common controls container
	commonControls := tk.NewFrame()
	commonControls.SetLayout(tk.NewHBoxLayout())
	commonControls.AddWidget(app.syncBtn)
	commonControls.AddWidget(tk.NewSeparator())
	commonControls.AddWidget(app.playAllBtn)
	commonControls.AddWidget(app.pauseAllBtn)
	commonControls.AddWidget(app.stopAllBtn)
	commonControls.AddWidget(tk.NewSeparator())
	commonControls.AddWidget(app.prevFrameBtn)
	commonControls.AddWidget(app.nextFrameBtn)

	// Stats display
	app.statsDisplay = tk.NewText()
	app.statsDisplay.SetText("Video Statistics\n\nLeft: No video loaded\nRight: No video loaded")

	// Left panel
	leftPanel := tk.NewFrame()
	leftPanel.SetLayout(tk.NewVBoxLayout())
	leftPanel.AddWidget(leftFileBtn)
	leftPanel.AddWidget(app.leftPlayer.fileLabel)
	leftPanel.AddWidget(app.leftPlayer.videoWidget)
	leftPanel.AddWidget(app.leftPlayer.progressBar)
	leftPanel.AddWidget(app.leftPlayer.timeLabel)
	leftPanel.AddWidget(leftControls)
	leftPanel.AddWidget(app.leftPlayer.statsLabel)

	// Right panel
	rightPanel := tk.NewFrame()
	rightPanel.SetLayout(tk.NewVBoxLayout())
	rightPanel.AddWidget(rightFileBtn)
	rightPanel.AddWidget(app.rightPlayer.fileLabel)
	rightPanel.AddWidget(app.rightPlayer.videoWidget)
	rightPanel.AddWidget(app.rightPlayer.progressBar)
	rightPanel.AddWidget(app.rightPlayer.timeLabel)
	rightPanel.AddWidget(rightControls)
	rightPanel.AddWidget(app.rightPlayer.statsLabel)

	// Main layout
	videoContainer := tk.NewFrame()
	videoContainer.SetLayout(tk.NewHBoxLayout())
	videoContainer.AddWidget(leftPanel)
	videoContainer.AddWidget(rightPanel)

	// Bottom panel with stats
	bottomPanel := tk.NewFrame()
	bottomPanel.SetLayout(tk.NewVBoxLayout())
	bottomPanel.AddWidget(commonControls)
	bottomPanel.AddWidget(tk.NewSeparator())
	bottomPanel.AddWidget(app.statsDisplay)

	// Main content
	mainLayout := tk.NewVBoxLayout()
	mainLayout.AddWidget(videoContainer)
	mainLayout.AddWidget(bottomPanel)

	app.window.SetLayout(mainLayout)
}

func (app *VideoCompareApp) createPlayerControls(player *VideoPlayer, side string) *tk.Frame {
	controls := tk.NewFrame()
	controls.SetLayout(tk.NewHBoxLayout())

	playBtn := tk.NewButton("Play")
	playBtn.OnCommand(func() {
		player.play()
	})

	pauseBtn := tk.NewButton("Pause")
	pauseBtn.OnCommand(func() {
		player.pause()
	})

	stopBtn := tk.NewButton("Stop")
	stopBtn.OnCommand(func() {
		player.stop()
	})

	// Time input for seeking
	timeInput := tk.NewEntry()
	timeInput.SetPlaceHolder("00:00:00")

	seekBtn := tk.NewButton("Seek")
	seekBtn.OnCommand(func() {
		if timeStr := timeInput.Text(); timeStr != "" {
			player.seekToTime(timeStr)
		}
	})

	controls.AddWidget(playBtn)
	controls.AddWidget(pauseBtn)
	controls.AddWidget(stopBtn)
	controls.AddWidget(tk.NewSeparator())
	controls.AddWidget(timeInput)
	controls.AddWidget(seekBtn)

	return controls
}

func (app *VideoCompareApp) selectVideoFile(player *VideoPlayer) {
	// For now, we'll use a simple file dialog
	// In a real implementation, you'd use Qt's file dialog
	filePath := tk.ChooseFile("Select Video File", "Video Files (*.mp4 *.mkv *.avi *.mov *.webm)")
	if filePath != "" {
		player.load(filePath)
		app.updateStats()
	}
}

func (player *VideoPlayer) load(path string) {
	player.path = path
	player.fileLabel.SetText(filepath.Base(path))

	// Set the media source
	player.mediaPlayer.SetSource(path)

	// Connect the media player to the video widget
	player.videoWidget.SetMediaPlayer(player.mediaPlayer)

	// Get media information
	player.extractMediaInfo()

	// Set up progress bar callback
	player.setupProgressCallback()

	// Update stats
	player.updateStats()
}

func (player *VideoPlayer) extractMediaInfo() {
	// Get duration
	player.duration = player.mediaPlayer.Duration() / 1000.0 // Convert to seconds

	// Get video information
	// Note: This is a simplified version. In a real implementation,
	// you'd get more detailed information from the media player
	player.width = 1920 // Default values
	player.height = 1080
	player.fps = 30.0
	player.bitrate = 0
}

func (player *VideoPlayer) setupProgressCallback() {
	// Set up a timer to update progress
	go func() {
		ticker := time.NewTicker(100 * time.Millisecond)
		defer ticker.Stop()

		for range ticker.C {
			if player.mediaPlayer != nil && player.isPlaying {
				player.currentTime = player.mediaPlayer.Position() / 1000.0

				// Update UI on main thread
				tk.QueueMain(func() {
					player.updateTimeDisplay()
					player.updateProgressBar()
				})
			}
		}
	}()
}

func (player *VideoPlayer) updateTimeDisplay() {
	current := formatTime(player.currentTime)
	total := formatTime(player.duration)
	player.timeLabel.SetText(fmt.Sprintf("%s / %s", current, total))
}

func (player *VideoPlayer) updateProgressBar() {
	if player.duration > 0 {
		progress := (player.currentTime / player.duration) * 100
		player.progressBar.SetValue(int(progress))
	}
}

func (player *VideoPlayer) updateStats() {
	stats := fmt.Sprintf("Resolution: %dx%d\nFPS: %.2f\nDuration: %s",
		player.width, player.height, player.fps, formatTime(player.duration))
	player.statsLabel.SetText(stats)
}

func (app *VideoCompareApp) updateStats() {
	leftStats := "No video loaded"
	rightStats := "No video loaded"

	if app.leftPlayer.path != "" {
		leftStats = fmt.Sprintf("File: %s\nResolution: %dx%d\nFPS: %.2f",
			filepath.Base(app.leftPlayer.path),
			app.leftPlayer.width, app.leftPlayer.height,
			app.leftPlayer.fps)
	}

	if app.rightPlayer.path != "" {
		rightStats = fmt.Sprintf("File: %s\nResolution: %dx%d\nFPS: %.2f",
			filepath.Base(app.rightPlayer.path),
			app.rightPlayer.width, app.rightPlayer.height,
			app.rightPlayer.fps)
	}

	combinedStats := fmt.Sprintf("Video Statistics\n\nLeft:\n%s\n\nRight:\n%s", leftStats, rightStats)
	app.statsDisplay.SetText(combinedStats)
}

// Playback controls
func (player *VideoPlayer) play() {
	if player.mediaPlayer != nil {
		player.mediaPlayer.Play()
		player.isPlaying = true
	}
}

func (player *VideoPlayer) pause() {
	if player.mediaPlayer != nil {
		player.mediaPlayer.Pause()
		player.isPlaying = false
	}
}

func (player *VideoPlayer) stop() {
	if player.mediaPlayer != nil {
		player.mediaPlayer.Stop()
		player.isPlaying = false
		player.currentTime = 0
		player.updateTimeDisplay()
		player.updateProgressBar()
	}
}

func (player *VideoPlayer) seekToTime(timeStr string) {
	if player.mediaPlayer == nil || player.duration == 0 {
		return
	}

	// Parse time string (HH:MM:SS or MM:SS)
	parts := strings.Split(timeStr, ":")
	var seconds float64

	if len(parts) == 3 {
		// HH:MM:SS
		h, _ := strconv.Atoi(parts[0])
		m, _ := strconv.Atoi(parts[1])
		s, _ := strconv.Atoi(parts[2])
		seconds = float64(h*3600 + m*60 + s)
	} else if len(parts) == 2 {
		// MM:SS
		m, _ := strconv.Atoi(parts[0])
		s, _ := strconv.Atoi(parts[1])
		seconds = float64(m*60 + s)
	}

	if seconds >= 0 && seconds <= player.duration {
		player.mediaPlayer.SetPosition(int64(seconds * 1000))
		player.currentTime = seconds
		player.updateTimeDisplay()
		player.updateProgressBar()
	}
}

// Common controls
func (app *VideoCompareApp) playAll() {
	app.leftPlayer.play()
	app.rightPlayer.play()
}

func (app *VideoCompareApp) pauseAll() {
	app.leftPlayer.pause()
	app.rightPlayer.pause()
}

func (app *VideoCompareApp) stopAll() {
	app.leftPlayer.stop()
	app.rightPlayer.stop()
}

func (app *VideoCompareApp) syncVideos() {
	// Sync both videos to the same timestamp
	if app.leftPlayer.currentTime > 0 {
		app.rightPlayer.seekToTime(formatTime(app.leftPlayer.currentTime))
	} else if app.rightPlayer.currentTime > 0 {
		app.leftPlayer.seekToTime(formatTime(app.rightPlayer.currentTime))
	}
}

// Frame-by-frame controls
func (app *VideoCompareApp) nextFrame() {
	// Calculate frame duration based on FPS
	if app.leftPlayer.fps > 0 {
		frameDuration := 1.0 / app.leftPlayer.fps
		newTime := app.leftPlayer.currentTime + frameDuration
		app.leftPlayer.seekToTime(formatTime(newTime))
	}

	if app.rightPlayer.fps > 0 {
		frameDuration := 1.0 / app.rightPlayer.fps
		newTime := app.rightPlayer.currentTime + frameDuration
		app.rightPlayer.seekToTime(formatTime(newTime))
	}
}

func (app *VideoCompareApp) previousFrame() {
	// Calculate frame duration based on FPS
	if app.leftPlayer.fps > 0 {
		frameDuration := 1.0 / app.leftPlayer.fps
		newTime := app.leftPlayer.currentTime - frameDuration
		if newTime >= 0 {
			app.leftPlayer.seekToTime(formatTime(newTime))
		}
	}

	if app.rightPlayer.fps > 0 {
		frameDuration := 1.0 / app.rightPlayer.fps
		newTime := app.rightPlayer.currentTime - frameDuration
		if newTime >= 0 {
			app.rightPlayer.seekToTime(formatTime(newTime))
		}
	}
}

func (app *VideoCompareApp) setupEventHandlers() {
	// Set up progress bar callbacks
	app.leftPlayer.progressBar.OnValueChanged(func(value int) {
		if app.leftPlayer.duration > 0 {
			newTime := (float64(value) / 100.0) * app.leftPlayer.duration
			app.leftPlayer.seekToTime(formatTime(newTime))
		}
	})

	app.rightPlayer.progressBar.OnValueChanged(func(value int) {
		if app.rightPlayer.duration > 0 {
			newTime := (float64(value) / 100.0) * app.rightPlayer.duration
			app.rightPlayer.seekToTime(formatTime(newTime))
		}
	})
}

// Utility functions
func formatTime(seconds float64) string {
	hours := int(seconds) / 3600
	minutes := (int(seconds) % 3600) / 60
	secs := int(seconds) % 60

	if hours > 0 {
		return fmt.Sprintf("%02d:%02d:%02d", hours, minutes, secs)
	}
	return fmt.Sprintf("%02d:%02d", minutes, secs)
}
