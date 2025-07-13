package main

import (
	"fmt"
	"log"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/canvas"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/storage"
	"fyne.io/fyne/v2/theme"
	"fyne.io/fyne/v2/widget"
	libvlc "github.com/adrg/libvlc-go/v3"
)

type VideoPlayer struct {
	player *libvlc.Player
	media  *libvlc.Media
	path   string
	title  string

	// UI elements
	fileLabel   *widget.Label
	timeLabel   *widget.Label
	statsLabel  *widget.Label
	progressBar *widget.Slider
	videoCanvas *canvas.Rectangle // Video display area

	// State
	isPlaying   bool
	currentTime float64
	duration    float64
	fps         float64
	width       int
	height      int
	bitrate     int
	codec       string
}

type VideoCompareApp struct {
	leftPlayer  *VideoPlayer
	rightPlayer *VideoPlayer

	// Common controls
	syncBtn     *widget.Button
	playAllBtn  *widget.Button
	pauseAllBtn *widget.Button
	stopAllBtn  *widget.Button

	// Frame controls
	prevFrameBtn *widget.Button
	nextFrameBtn *widget.Button

	// Stats display
	statsDisplay *widget.TextGrid

	window fyne.Window
}

func main() {
	// Initialize libVLC
	if err := libvlc.Init(""); err != nil {
		log.Fatalf("failed to init libvlc: %v", err)
	}
	defer libvlc.Release()

	myApp := app.New()
	myApp.SetIcon(theme.ComputerIcon())

	window := myApp.NewWindow("Video Compare - Advanced Side-by-Side Comparison")
	window.Resize(fyne.NewSize(1600, 1000))
	window.CenterOnScreen()

	app := &VideoCompareApp{
		window: window,
	}

	app.initializePlayers()
	app.createUI()
	app.setupEventHandlers()

	window.ShowAndRun()
}

func (app *VideoCompareApp) initializePlayers() {
	app.leftPlayer = newVideoPlayer("Left Video")
	app.rightPlayer = newVideoPlayer("Right Video")
}

func newVideoPlayer(title string) *VideoPlayer {
	player, err := libvlc.NewPlayer()
	if err != nil {
		log.Fatalf("failed to create vlc player: %v", err)
	}

	return &VideoPlayer{
		player:      player,
		title:       title,
		fileLabel:   widget.NewLabel("No file selected"),
		timeLabel:   widget.NewLabel("00:00 / 00:00"),
		statsLabel:  widget.NewLabel("No video loaded"),
		progressBar: widget.NewSlider(0, 100),
		videoCanvas: canvas.NewRectangle(theme.BackgroundColor()),
	}
}

func (app *VideoCompareApp) createUI() {
	// Create file selection buttons
	leftFileBtn := widget.NewButtonWithIcon("Choose Left Video", theme.FolderOpenIcon(), func() {
		app.selectVideoFile(app.leftPlayer)
	})

	rightFileBtn := widget.NewButtonWithIcon("Choose Right Video", theme.FolderOpenIcon(), func() {
		app.selectVideoFile(app.rightPlayer)
	})

	// Individual player controls
	leftControls := app.createPlayerControls(app.leftPlayer, "Left")
	rightControls := app.createPlayerControls(app.rightPlayer, "Right")

	// Common controls
	app.syncBtn = widget.NewButtonWithIcon("Sync Videos", theme.MediaSkipNextIcon(), app.syncVideos)
	app.playAllBtn = widget.NewButtonWithIcon("Play All", theme.MediaPlayIcon(), app.playAll)
	app.pauseAllBtn = widget.NewButtonWithIcon("Pause All", theme.MediaPauseIcon(), app.pauseAll)
	app.stopAllBtn = widget.NewButtonWithIcon("Stop All", theme.MediaStopIcon(), app.stopAll)

	// Frame controls
	app.prevFrameBtn = widget.NewButtonWithIcon("Previous Frame", theme.MediaSkipPreviousIcon(), app.previousFrame)
	app.nextFrameBtn = widget.NewButtonWithIcon("Next Frame", theme.MediaSkipNextIcon(), app.nextFrame)

	// Common controls container
	commonControls := container.NewHBox(
		app.syncBtn,
		widget.NewSeparator(),
		app.playAllBtn,
		app.pauseAllBtn,
		app.stopAllBtn,
		widget.NewSeparator(),
		app.prevFrameBtn,
		app.nextFrameBtn,
	)

	// Stats display
	app.statsDisplay = widget.NewTextGrid()
	app.statsDisplay.SetText("Video Statistics\n\nLeft: No video loaded\nRight: No video loaded")

	// Left panel
	leftPanel := container.NewVBox(
		leftFileBtn,
		app.leftPlayer.fileLabel,
		app.leftPlayer.videoCanvas, // Video display area
		app.leftPlayer.progressBar,
		app.leftPlayer.timeLabel,
		leftControls,
		app.leftPlayer.statsLabel,
	)

	// Right panel
	rightPanel := container.NewVBox(
		rightFileBtn,
		app.rightPlayer.fileLabel,
		app.rightPlayer.videoCanvas, // Video display area
		app.rightPlayer.progressBar,
		app.rightPlayer.timeLabel,
		rightControls,
		app.rightPlayer.statsLabel,
	)

	// Main layout
	videoContainer := container.NewHSplit(leftPanel, rightPanel)
	videoContainer.SetOffset(0.5)

	// Bottom panel with stats
	bottomPanel := container.NewVBox(
		commonControls,
		widget.NewSeparator(),
		app.statsDisplay,
	)

	// Main content
	content := container.NewBorder(nil, bottomPanel, nil, nil, videoContainer)
	app.window.SetContent(content)
}

func (app *VideoCompareApp) createPlayerControls(player *VideoPlayer, side string) *fyne.Container {
	playBtn := widget.NewButtonWithIcon("Play", theme.MediaPlayIcon(), func() {
		player.play()
	})

	pauseBtn := widget.NewButtonWithIcon("Pause", theme.MediaPauseIcon(), func() {
		player.pause()
	})

	stopBtn := widget.NewButtonWithIcon("Stop", theme.MediaStopIcon(), func() {
		player.stop()
	})

	// Time input for seeking
	timeInput := widget.NewEntry()
	timeInput.SetPlaceHolder("00:00:00")

	seekBtn := widget.NewButton("Seek", func() {
		if timeStr := timeInput.Text; timeStr != "" {
			player.seekToTime(timeStr)
		}
	})

	controls := container.NewHBox(
		playBtn,
		pauseBtn,
		stopBtn,
		widget.NewSeparator(),
		timeInput,
		seekBtn,
	)

	return controls
}

func (app *VideoCompareApp) selectVideoFile(player *VideoPlayer) {
	fd := dialog.NewFileOpen(func(reader fyne.URIReadCloser, err error) {
		if err != nil || reader == nil {
			return
		}
		path := reader.URI().Path()
		player.load(path)
		app.updateStats()
	}, app.window)

	// Support for more video formats
	fd.SetFilter(storage.NewExtensionFileFilter([]string{
		".mp4", ".mkv", ".avi", ".mov", ".webm", ".flv", ".wmv", ".m4v", ".3gp", ".ogv", ".ts", ".mts", ".m2ts",
	}))
	fd.Show()
}

func (vp *VideoPlayer) load(path string) {
	vp.path = path
	vp.fileLabel.SetText(filepath.Base(path))

	media, err := libvlc.NewMediaFromPath(path)
	if err != nil {
		log.Printf("failed to load media: %v", err)
		return
	}

	vp.media = media
	vp.player.SetMedia(media)

	// Removed SetOption (not available in libvlc-go)
	// vp.player.SetOption("--no-xlib")

	// Get media information
	vp.extractMediaInfo()

	// Set up progress bar callback
	vp.setupProgressCallback()

	// Update stats
	vp.updateStats()

	// Update video canvas to show video info
	vp.updateVideoCanvas()
}

func (vp *VideoPlayer) updateVideoCanvas() {
	// Create a visual representation of the video
	if vp.width > 0 && vp.height > 0 {
		// Set canvas size based on video dimensions (scaled down for GUI)
		scale := 0.3 // Scale factor for GUI display
		canvasWidth := int(float64(vp.width) * scale)
		canvasHeight := int(float64(vp.height) * scale)

		vp.videoCanvas.Resize(fyne.NewSize(float32(canvasWidth), float32(canvasHeight)))
		vp.videoCanvas.FillColor = theme.PrimaryColor()
		vp.videoCanvas.Refresh()
	} else {
		// Default size for no video
		vp.videoCanvas.Resize(fyne.NewSize(320, 240))
		vp.videoCanvas.FillColor = theme.DisabledColor()
		vp.videoCanvas.Refresh()
	}
}

func (vp *VideoPlayer) extractMediaInfo() {
	if vp.media == nil {
		return
	}

	_ = vp.media.Parse() // ignore error for now
	// Get duration
	duration, err := vp.media.Duration()
	if err == nil {
		vp.duration = float64(duration) / 1000.0 // Convert to seconds
	}
	// Get tracks information
	tracks, err := vp.media.Tracks()
	if err == nil && len(tracks) > 0 {
		for _, track := range tracks {
			if track.Type == libvlc.MediaTrackVideo {
				videoTrack := track.Video
				if videoTrack != nil {
					vp.width = int(videoTrack.Width)
					vp.height = int(videoTrack.Height)
					if videoTrack.FrameRateDen != 0 {
						vp.fps = float64(videoTrack.FrameRateNum) / float64(videoTrack.FrameRateDen)
					}
					break
				}
			}
		}
	}
	vp.bitrate = 0
}

func (vp *VideoPlayer) setupProgressCallback() {
	// Set up a timer to update progress
	go func() {
		ticker := time.NewTicker(100 * time.Millisecond)
		defer ticker.Stop()
		for range ticker.C {
			if vp.player != nil && vp.isPlaying {
				timeMs, err := vp.player.MediaTime()
				if err == nil {
					vp.currentTime = float64(timeMs) / 1000.0
					vp.updateTimeDisplay()
					vp.updateProgressBar()
				}
			}
		}
	}()
}

func (vp *VideoPlayer) updateTimeDisplay() {
	current := formatTime(vp.currentTime)
	total := formatTime(vp.duration)
	vp.timeLabel.SetText(fmt.Sprintf("%s / %s", current, total))
}

func (vp *VideoPlayer) updateProgressBar() {
	if vp.duration > 0 {
		progress := (vp.currentTime / vp.duration) * 100
		vp.progressBar.SetValue(progress)
	}
}

func (vp *VideoPlayer) updateStats() {
	stats := fmt.Sprintf("Resolution: %dx%d\nFPS: %.2f\nDuration: %s",
		vp.width, vp.height, vp.fps, formatTime(vp.duration))
	vp.statsLabel.SetText(stats)
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
func (vp *VideoPlayer) play() {
	if vp.player != nil {
		vp.player.Play()
		vp.isPlaying = true
	}
}

func (vp *VideoPlayer) pause() {
	if vp.player != nil {
		vp.player.SetPause(true)
		vp.isPlaying = false
	}
}

func (vp *VideoPlayer) stop() {
	if vp.player != nil {
		vp.player.Stop()
		vp.isPlaying = false
		vp.currentTime = 0
		vp.updateTimeDisplay()
		vp.updateProgressBar()
	}
}

func (vp *VideoPlayer) seekToTime(timeStr string) {
	if vp.player == nil || vp.duration == 0 {
		return
	}
	// Parse time string (HH:MM:SS or MM:SS)
	parts := strings.Split(timeStr, ":")
	var seconds float64
	if len(parts) == 3 {
		h, _ := strconv.Atoi(parts[0])
		m, _ := strconv.Atoi(parts[1])
		s, _ := strconv.Atoi(parts[2])
		seconds = float64(h*3600 + m*60 + s)
	} else if len(parts) == 2 {
		m, _ := strconv.Atoi(parts[0])
		s, _ := strconv.Atoi(parts[1])
		seconds = float64(m*60 + s)
	}
	if seconds >= 0 && seconds <= vp.duration {
		_ = vp.player.SetMediaTime(int(seconds * 1000))
		vp.currentTime = seconds
		vp.updateTimeDisplay()
		vp.updateProgressBar()
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
	app.leftPlayer.progressBar.OnChanged = func(value float64) {
		if app.leftPlayer.duration > 0 {
			newTime := (value / 100.0) * app.leftPlayer.duration
			app.leftPlayer.seekToTime(formatTime(newTime))
		}
	}

	app.rightPlayer.progressBar.OnChanged = func(value float64) {
		if app.rightPlayer.duration > 0 {
			newTime := (value / 100.0) * app.rightPlayer.duration
			app.rightPlayer.seekToTime(formatTime(newTime))
		}
	}
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
