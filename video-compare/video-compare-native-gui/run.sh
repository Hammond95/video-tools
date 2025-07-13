#!/bin/bash

# Set up VLC environment variables for macOS
export CGO_CFLAGS="-I/Applications/VLC.app/Contents/MacOS/include"
export CGO_LDFLAGS="-L/Applications/VLC.app/Contents/MacOS/lib -lvlc"
export VLC_PLUGIN_PATH="/Applications/VLC.app/Contents/MacOS/plugins"
export DYLD_LIBRARY_PATH="/Applications/VLC.app/Contents/MacOS/lib:$DYLD_LIBRARY_PATH"

# Run the video comparison application
./video-compare-native-gui 