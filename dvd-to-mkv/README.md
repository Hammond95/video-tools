# DVD to MKV Converter

A comprehensive bash script to convert DVD files to MKV format with integrated subtitles and metadata extraction.

## Features

- **Automatic subtitle detection and integration**: Extracts all available subtitle streams from the DVD
- **Metadata extraction**: Saves detailed DVD metadata to a JSON file
- **Flexible stream selection**: Choose specific audio and subtitle streams
- **Multiple quality options**: Copy original streams or re-encode to H.264/H.265
- **Custom metadata support**: Use JSON files for custom metadata
- **Colored output**: Easy-to-read status messages
- **Comprehensive error handling**: Detailed error messages and validation

## Requirements

- **ffmpeg**: For video/audio processing
- **ffprobe**: For media analysis (usually comes with ffmpeg)
- **jq**: For JSON processing

### Installation

**macOS:**
```bash
brew install ffmpeg jq
```

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install ffmpeg jq
```

**CentOS/RHEL:**
```bash
sudo yum install ffmpeg jq
```

## Usage

### Basic Usage

```bash
./dvd-to-mkv.sh <path_to_VIDEO_TS_folder> <output_file.mkv>
```

### Advanced Usage

```bash
./dvd-to-mkv.sh <path_to_VIDEO_TS_folder> <output_file.mkv> [options]
```

### Options

- `-t, --title <number>`: DVD title number to extract (default: auto-detect)
- `-s, --subtitles <list>`: Comma-separated list of subtitle streams to include (default: all)
- `-a, --audio <list>`: Comma-separated list of audio streams to include (default: all)
- `-q, --quality <level>`: Video quality: `copy`, `h264`, `h265`, `h265fast`, `h265hw`, `repair` (default: `copy`)
- `-p, --preserve-audio`: Preserve original audio codec (don't convert to AAC)
- `-m, --metadata <file>`: JSON file with custom metadata
- `-h, --help`: Show help message

### Examples

**Basic conversion:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv
```

**Convert with specific title and subtitle streams:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -t 1 -s 0,1
```

**Convert with H.264 re-encoding:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -q h264
```

**Convert with H.265 (best quality/size ratio):**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -q h265
```

**Convert with fast H.265:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -q h265fast
```

**Convert with hardware-accelerated H.265 (macOS):**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -q h265hw
```

**Convert with preserved audio codec:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -q h265 -p
```

**Convert with custom metadata:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv --metadata metadata.json
```

**Convert with specific audio streams:**
```bash
./dvd-to-mkv.sh /path/to/VIDEO_TS movie.mkv -a 0,1
```

## Custom Metadata

You can provide custom metadata using a JSON file:

```json
{
  "title": "My Movie Title",
  "author": "Movie Director",
  "comment": "Custom comment about the movie"
}
```

## Output Files

The script generates two files:

1. **MKV file**: The converted movie with integrated subtitles
2. **Metadata JSON file**: Detailed information about the DVD and streams (named `{output}_metadata.json`)

## Quality Options

The script supports multiple quality modes for different use cases:

### Available Quality Modes

- **`copy`**: Preserves original video/audio streams (fastest, no quality loss)
- **`h264`**: Re-encodes video to H.264 with high quality settings
- **`h265`**: Re-encodes video to H.265 (HEVC) with optimized threading
- **`h265fast`**: Fast H.265 encoding with reduced quality
- **`h265hw`**: Hardware-accelerated H.265 encoding (macOS only)
- **`repair`**: Re-encodes with error tolerance for problematic DVDs

### Quality Comparison Table

| Quality Setting | Speed | File Size | Quality | Use Case |
|----------------|-------|-----------|---------|----------|
| `copy` | ⚡⚡⚡⚡⚡ (Fastest) | Original | Perfect | Archival, fastest conversion |
| `h264` | ⚡⚡⚡⚡ (Fast) | ~50-70% of original | Excellent | Universal compatibility |
| `h265` | ⚡⚡⚡ (Medium) | ~50-70% of H.264 | Excellent | Best quality/size ratio |
| `h265fast` | ⚡⚡⚡⚡ (Fast) | ~60-80% of H.264 | Very Good | Quick H.265 conversion |
| `h265hw` | ⚡⚡⚡⚡⚡ (Fastest) | ~50-70% of H.264 | Very Good | Hardware acceleration |
| `repair` | ⚡⚡ (Slow) | ~2-3x larger | Good | Corrupted DVDs |

### Detailed Quality Settings

| Mode | Video Codec | Preset | CRF/Bitrate | Audio | Threading | Notes |
|------|-------------|--------|-------------|-------|-----------|-------|
| `copy` | Original | N/A | N/A | Original/AAC | N/A | No re-encoding |
| `h264` | libx264 | slow | CRF 18 | AAC | Standard | High quality H.264 |
| `h265` | libx265 | slow | CRF 20 | AAC | Optimized | Best quality/size |
| `h265fast` | libx265 | fast | CRF 24 | AAC | Optimized | Fast H.265 |
| `h265hw` | hevc_videotoolbox | N/A | 5000k | AAC | Hardware | macOS only |
| `repair` | libx264 | medium | CRF 23 | AAC | Standard | Error tolerant |

### Speed vs Quality Trade-offs

- **For fastest conversion**: Use `copy` or `h265hw` (if on macOS)
- **For best quality**: Use `h265` with `-p` (preserve audio)
- **For universal compatibility**: Use `h264`
- **For smallest file size**: Use `h265`
- **For problematic DVDs**: Use `repair`

### Audio Options

Add `-p` or `--preserve-audio` to keep original audio codecs instead of converting to AAC:

```bash
# Keep original DTS/AC3 audio
./dvd-to-mkv.sh "path/to/dvd" "output.mkv" -q h265 -p

# Convert to AAC (default)
./dvd-to-mkv.sh "path/to/dvd" "output.mkv" -q h265
```

## Troubleshooting

### Common Issues

1. **"Missing dependencies"**: Install ffmpeg, ffprobe, and jq
2. **"DVD path does not exist"**: Check the path to your VIDEO_TS folder
3. **"Could not retrieve title information"**: The DVD structure might be corrupted or incomplete
4. **Conversion fails**: Check if the DVD has copy protection or is damaged

### Tips

- Use `copy` quality for the fastest conversion and best quality preservation
- Use `h264` or `h265` for smaller file sizes but longer conversion times
- The script automatically creates output directories if they don't exist
- All subtitle streams are included by default - use `-s` to select specific ones
- The script shows available titles and streams before conversion

## File Structure

Your DVD folder should contain a `VIDEO_TS` directory with files like:
```
VIDEO_TS/
├── VIDEO_TS.IFO
├── VIDEO_TS.VOB
├── VTS_01_0.IFO
├── VTS_01_0.VOB
├── VTS_01_1.VOB
└── ...
```

## License

This script is provided as-is for educational and personal use. 