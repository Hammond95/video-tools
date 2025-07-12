package main

import (
	"log"
	"path/filepath"

	"fyne.io/fyne/v2"
	"fyne.io/fyne/v2/app"
	"fyne.io/fyne/v2/container"
	"fyne.io/fyne/v2/dialog"
	"fyne.io/fyne/v2/storage"
	"fyne.io/fyne/v2/widget"
	"github.com/adrg/libvlc-go/v3"
)

func main() {
	// Initialize libVLC. You may need to set VLC_PLUGIN_PATH if VLC is not in a standard location.
	if err := libvlc.Init(""); err != nil {
		log.Fatalf("failed to init libvlc: %v", err)
	}
	defer libvlc.Release()

	myApp := app.New()
	w := myApp.NewWindow("Video Compare Native GUI")
	w.Resize(fyne.NewSize(1400, 900))

	// Video player state
	leftPlayer := newVLCPlayer()
	rightPlayer := newVLCPlayer()

	// File pickers
	leftFileLabel := widget.NewLabel("No file selected")
	leftFileBtn := widget.NewButton("Choose File", func() {
		fd := dialog.NewFileOpen(func(reader fyne.URIReadCloser, err error) {
			if err != nil || reader == nil {
				return
			}
			path := reader.URI().Path()
			leftFileLabel.SetText(filepath.Base(path))
			leftPlayer.load(path)
		}, w)
		fd.SetFilter(storage.NewExtensionFileFilter([]string{".mp4", ".mkv", ".avi", ".mov", ".webm"}))
		fd.Show()
	})

	rightFileLabel := widget.NewLabel("No file selected")
	rightFileBtn := widget.NewButton("Choose File", func() {
		fd := dialog.NewFileOpen(func(reader fyne.URIReadCloser, err error) {
			if err != nil || reader == nil {
				return
			}
			path := reader.URI().Path()
			rightFileLabel.SetText(filepath.Base(path))
			rightPlayer.load(path)
		}, w)
		fd.SetFilter(storage.NewExtensionFileFilter([]string{".mp4", ".mkv", ".avi", ".mov", ".webm"}))
		fd.Show()
	})

	// Controls (play/pause, etc.)
	leftControls := container.NewHBox(
		widget.NewButton("Play", func() { leftPlayer.play() }),
		widget.NewButton("Pause", func() { leftPlayer.pause() }),
	)
	rightControls := container.NewHBox(
		widget.NewButton("Play", func() { rightPlayer.play() }),
		widget.NewButton("Pause", func() { rightPlayer.pause() }),
	)

	leftPanel := container.NewVBox(leftFileBtn, leftFileLabel, leftControls)
	rightPanel := container.NewVBox(rightFileBtn, rightFileLabel, rightControls)

	w.SetContent(container.NewHSplit(leftPanel, rightPanel))
	w.ShowAndRun()
}

type vlcPlayer struct {
	player *libvlc.Player
}

func newVLCPlayer() *vlcPlayer {
	mp, err := libvlc.NewPlayer()
	if err != nil {
		log.Fatalf("failed to create vlc player: %v", err)
	}
	return &vlcPlayer{player: mp}
}

func (vp *vlcPlayer) load(path string) {
	media, err := libvlc.NewMediaFromPath(path)
	if err != nil {
		log.Printf("failed to load media: %v", err)
		return
	}
	vp.player.SetMedia(media)
}

func (vp *vlcPlayer) play() {
	vp.player.Play()
}

func (vp *vlcPlayer) pause() {
	vp.player.SetPause(true)
}
