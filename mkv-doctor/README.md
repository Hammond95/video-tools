# MKV Doctor

A comprehensive diagnostic and repair tool for MKV files. This script analyzes MKV files for common issues that can cause playback problems in media players like VLC, and provides repair options.

## Features

### Analysis Capabilities
- **Basic File Information**: File size, permissions, modification date
- **MKV Structure Analysis**: Validates EBML header, segments, tracks, and clusters
- **Stream Analysis**: Detailed analysis of video, audio, subtitle, and attachment streams
- **Corruption Detection**: Identifies corrupted data, decoding errors, and invalid timestamps
- **Audio/Video Sync Check**: Detects synchronization issues between audio and video streams
- **Quick Check Mode**: Fast analysis for obvious issues
- **Deep Analysis Mode**: Advanced analysis including stress testing and compatibility checks
- **Timing Analysis**: Detects negative timestamps, large gaps, and duplicate timestamps
- **Container Analysis**: Uses mkvmerge to detect container-specific issues
- **Playback Compatibility**: Checks for problematic codecs and configurations
- **Stress Testing**: Tests seeking to various positions to detect intermittent issues

### Repair Capabilities
- **Automatic Repair**: Attempts to fix detected issues using FFmpeg
- **Error Correction**: Uses error detection and correction flags
- **Backup Creation**: Optional backup of original files before repair
- **Force Mode**: Aggressive repair for severely damaged files

## Dependencies

The script requires the following tools to be installed:

- **ffmpeg**: For video processing and repair
- **ffprobe**: For stream analysis
- **mkvmerge**: For MKV manipulation (part of mkvtoolnix)
- **mkvinfo**: For MKV structure analysis (part of mkvtoolnix)
- **jq**: For JSON parsing
- **bc**: For mathematical calculations

### Installation

**macOS:**
```bash
brew install ffmpeg mkvtoolnix jq bc
```

**Ubuntu/Debian:**
```bash
sudo apt install ffmpeg mkvtoolnix jq bc
```

**CentOS/RHEL:**
```bash
sudo yum install ffmpeg mkvtoolnix jq bc
```

## Usage

### Basic Usage

```bash
# Full analysis of an MKV file
./mkv-doctor.sh movie.mkv

# Quick check for obvious issues
./mkv-doctor.sh movie.mkv --check-only

# Analysis with detailed output
./mkv-doctor.sh movie.mkv --verbose

# Deep analysis with stress testing (recommended for problematic files)
./mkv-doctor.sh movie.mkv --deep

# Deep analysis with verbose output
./mkv-doctor.sh movie.mkv --deep --verbose

# Analyze and attempt repair
./mkv-doctor.sh movie.mkv --repair

# Repair with backup of original file
./mkv-doctor.sh movie.mkv --repair --backup

# Force repair for severely damaged files
./mkv-doctor.sh movie.mkv --repair --force

# Specify output file for repaired version
./mkv-doctor.sh movie.mkv --repair --output fixed_movie.mkv
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-a, --analyze-only` | Only analyze the file, don't attempt repairs |
| `-r, --repair` | Attempt to repair detected issues |
| `-f, --force` | Force repair even if issues are minor |
| `-v, --verbose` | Show detailed analysis information |
| `-o, --output <file>` | Specify output file for repaired version |
| `-b, --backup` | Create backup of original file before repair |
| `-c, --check-only` | Quick check for obvious issues |
| `-d, --deep` | Perform deep analysis (includes stress testing) |
| `-h, --help` | Show help message |

## Advanced Analysis Features

### Deep Stream Analysis
- **Codec Profile Detection**: Identifies problematic H.264 profiles (High 4:4:4, Level 5.2)
- **Audio Configuration**: Detects high channel counts, sample rates, and problematic DTS configurations
- **Pixel Format Validation**: Checks for unknown or unsupported pixel formats
- **Reference Frame Analysis**: Identifies potential B-frame and reference frame issues

### Timing Analysis
- **Negative Timestamps**: Detects packets with negative presentation timestamps
- **Large Gaps**: Identifies timestamp gaps greater than 10 seconds
- **Duplicate Timestamps**: Finds packets with identical timestamps
- **Timing Consistency**: Validates overall timing structure

### Container Analysis
- **mkvmerge Integration**: Uses mkvmerge for container-specific validation
- **Track Validation**: Ensures proper video and audio track presence
- **Warning Detection**: Identifies mkvmerge warnings and errors
- **Unusual Track Types**: Detects non-standard track types

### Playback Compatibility
- **Codec Support**: Checks for problematic codecs (HEVC, VP9, AV1, Opus, FLAC)
- **File Size Limits**: Warns about very large files (>10GB)
- **Duration Limits**: Alerts about very long durations (>4 hours)
- **Metadata Issues**: Detects overly long title/artist tags

### Stress Testing
- **Seek Testing**: Tests seeking to multiple positions (0s, 10s, 30s, 60s, 120s, 300s)
- **End-of-File Testing**: Validates seeking near the end of the file
- **Playback Stability**: Identifies intermittent issues that occur during seeking
- **Error Detection**: Captures and reports seeking failures

## Common Issues Detected

### Structural Issues
- Missing EBML header
- Missing segment information
- Missing track information
- Missing cluster data
- Corrupted MKV container structure

### Stream Issues
- Missing video or audio streams
- Unknown or unsupported codecs
- Zero channel audio streams
- Missing resolution information
- Invalid stream parameters
- Problematic codec profiles (H.264 High 4:4:4, Level 5.2)
- High channel count audio (>8 channels)
- High sample rate audio (>96kHz)

### Corruption Issues
- Invalid data found in streams
- Decoding errors
- Invalid timestamps
- Oversized packets
- File integrity problems
- Negative presentation timestamps
- Large timestamp gaps
- Duplicate timestamps

### Sync Issues
- Audio/video synchronization problems
- Large timing differences between streams
- Start time mismatches

### Compatibility Issues
- Unsupported codecs (HEVC, VP9, AV1, Opus, FLAC)
- Very large files (>10GB)
- Very long durations (>4 hours)
- Problematic metadata tags

### Intermittent Issues
- Seeking failures at specific positions
- Playback instability during seeking
- End-of-file playback problems
- Stress test failures

## Repair Process

When repair is requested, the script:

1. **Creates Backup** (if `--backup` is specified)
2. **Analyzes Issues** to determine repair strategy
3. **Runs FFmpeg Repair** with error correction flags:
   - `-fflags +genpts`: Regenerates presentation timestamps
   - `-err_detect ignore_err`: Ignores minor errors
   - `-avoid_negative_ts make_zero`: Fixes negative timestamps
   - `-c copy`: Preserves original codecs when possible
4. **Verifies Repair** by running integrity check on repaired file
5. **Reports Results** with success/failure status

## Output Examples

### Successful Analysis
```
[HEADER] Starting MKV Analysis
File: movie.mkv

[HEADER] Basic File Information
  File: movie.mkv
  Size: 2048MB (2GB)
  Permissions: -rw-r--r--
  Modified: Dec 15 10:30:45 2024

[HEADER] MKV Structure Analysis
  EBML Header: ✓ Present
  Segment: ✓ Present
  Tracks: ✓ Present
  Clusters: ✓ Present
[SUCCESS] MKV structure appears valid

[HEADER] Stream Analysis
  Video streams: 1
  Audio streams: 2
  Subtitle streams: 3
  Attachments: 0

[HEADER] Analysis Summary
[SUCCESS] No issues detected - file appears to be healthy
```

### Issues Detected
```
[HEADER] Analysis Summary
[WARNING] 2 issue(s) detected
    - Audio/video sync issue detected
    - Invalid timestamps detected

[HEADER] Attempting Repair
[INFO] Repairing file: movie.mkv
[INFO] Output file: movie_repaired.mkv
[SUCCESS] Repair completed successfully
[SUCCESS] Repaired file verification passed
```

### Deep Analysis Example
```
[HEADER] Starting Deep Analysis (with Stress Test)
File: problematic.mkv

[HEADER] Deep Stream Analysis
  Video stream analysis:
    Stream 0: h264 (profile: High 4:4:4, level: 5.2)
      Pixel format: yuv420p, B-frames: 3, Refs: 16
    [WARNING] - High 4:4:4 profile can cause playback issues in some players
    [WARNING] - H.264 Level 5.2 may not be supported by all players

[HEADER] Timing Analysis
  Total packets: 125847
  [WARNING] Found 15 packets with negative timestamps
  [WARNING] Found 3 large timestamp gaps (>10s)

[HEADER] Stress Test Analysis
  [INFO] Testing seek to 0s...
  [INFO] Testing seek to 10s...
  [WARNING] Seek to 120s failed
  [WARNING] Seek to 300s failed

[HEADER] Analysis Summary
[WARNING] 6 issue(s) detected
```

## Troubleshooting

### Script Won't Run
- Check that all dependencies are installed
- Ensure the script has execute permissions (`chmod +x mkv-doctor.sh`)
- Verify the file path is correct

### Analysis Fails
- File may be severely corrupted
- File may not be a valid MKV
- Insufficient permissions to read the file

### Repair Fails
- File may be too severely damaged
- Try using `--force` option for aggressive repair
- Check available disk space for output file
- Ensure write permissions in output directory

### False Positives
- Some warnings may be false positives
- Use `--verbose` for more detailed information
- Check if the file plays correctly despite warnings

### Intermittent Issues Not Detected
- Use `--deep` mode for comprehensive analysis
- The stress test specifically targets seeking issues
- Deep analysis includes compatibility checks for problematic codecs

## Integration with DVD-to-MKV

This tool is designed to work alongside the `dvd-to-mkv.sh` script. After converting DVDs to MKV, you can use MKV Doctor to:

1. **Verify Conversion Quality**: Check if the converted MKV is healthy
2. **Detect Conversion Issues**: Identify problems that occurred during conversion
3. **Repair Conversion Artifacts**: Fix common issues from the conversion process
4. **Quality Assurance**: Ensure the final MKV file is ready for playback
5. **Deep Validation**: Use `--deep` mode to catch subtle issues that cause intermittent problems

## License

This tool is part of the video-tools collection and follows the same licensing terms.

## Contributing

Feel free to submit issues, feature requests, or pull requests to improve the tool. 