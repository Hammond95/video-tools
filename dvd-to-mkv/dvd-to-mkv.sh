#!/bin/bash

# DVD to MKV Converter
# Main script that orchestrates the conversion process using library functions

# Source libraries
source "$(dirname "$0")/lib_utils.sh"
source "$(dirname "$0")/lib_dvd.sh"
source "$(dirname "$0")/lib_ffmpeg.sh"

# Parse command line arguments
DVD_PATH=""
OUTPUT_FILE=""
TITLE_NUM=""
SUBTITLE_STREAMS=""
AUDIO_STREAMS=""
SINGLE_AUDIO=false
QUALITY="copy"
PRESERVE_AUDIO=false
METADATA_FILE=""
LIST_TITLES=false
SHOW_INFO=false
USE_FFMPEG_CONCAT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--title)
            TITLE_NUM="$2"
            shift 2
            ;;
        -s|--subtitles)
            SUBTITLE_STREAMS="$2"
            shift 2
            ;;
        -a|--audio)
            AUDIO_STREAMS="$2"
            shift 2
            ;;
        -S|--single-audio)
            SINGLE_AUDIO=true
            shift
            ;;
        -q|--quality)
            QUALITY="$2"
            shift 2
            ;;
        -p|--preserve-audio)
            PRESERVE_AUDIO=true
            shift
            ;;
        -m|--metadata)
            METADATA_FILE="$2"
            shift 2
            ;;
        -l|--list-titles)
            LIST_TITLES=true
            shift
            ;;
        -i|--info)
            SHOW_INFO=true
            shift
            ;;
        --ffmpeg-concat)
            USE_FFMPEG_CONCAT=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        -*)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [ -z "$DVD_PATH" ]; then
                DVD_PATH="$1"
            elif [ -z "$OUTPUT_FILE" ]; then
                OUTPUT_FILE="$1"
            else
                print_error "Too many arguments"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required arguments
if [ -z "$DVD_PATH" ]; then
    print_error "Missing DVD path"
    show_usage
    exit 1
fi

# Handle special modes
if [ "$LIST_TITLES" = true ]; then
    check_dependencies
    list_titles "$DVD_PATH"
    exit 0
fi

if [ "$SHOW_INFO" = true ]; then
    check_dependencies
    show_dvd_info "$DVD_PATH"
    exit 0
fi

if [ -z "$OUTPUT_FILE" ]; then
    print_error "Missing output file"
    show_usage
    exit 1
fi

# Validate DVD path
if [ ! -d "$DVD_PATH" ]; then
    print_error "DVD path does not exist: $DVD_PATH"
    exit 1
fi

# Check dependencies
check_dependencies

# Validate DVD structure
video_ts_path=$(validate_dvd_structure "$DVD_PATH")

# Create output directory if it doesn't exist
output_dir=$(dirname "$OUTPUT_FILE")
if [ ! -d "$output_dir" ]; then
    mkdir -p "$output_dir"
fi

# Auto-detect title if not specified
if [ -z "$TITLE_NUM" ]; then
    TITLE_NUM=$(auto_select_title "$video_ts_path")
fi

# List available titles
list_titles "$video_ts_path"
echo ""

# Show stream information for selected title
get_stream_info "$video_ts_path" "$TITLE_NUM"
echo ""

# Validate streams
validate_subtitle_streams "$video_ts_path" "$SUBTITLE_STREAMS" "$TITLE_NUM"
validate_audio_streams "$video_ts_path" "$AUDIO_STREAMS" "$TITLE_NUM"

# Concatenate VOB files if needed
input_file=$(concatenate_vob_files "$video_ts_path" "$TITLE_NUM" "$USE_FFMPEG_CONCAT")
if [ $? -ne 0 ]; then
    print_error "Failed to prepare input file"
    exit 1
fi

# Interactive audio selection
if [ "$SINGLE_AUDIO" = true ]; then
    print_status "Interactive audio track selection enabled"
    select_single_audio "$input_file"
    selection_exit_code=$?
    
    if [ $selection_exit_code -eq 0 ]; then
        if [ -n "$SELECTED_AUDIO_MAPPING" ]; then
            print_status "Audio selection successful: $SELECTED_AUDIO_MAPPING"
        else
            print_error "Audio selection failed: no mapping selected"
            exit 1
        fi
    else
        print_error "Audio selection failed with exit code $selection_exit_code"
        exit 1
    fi
fi

# Map audio streams (selected or all)
map_audio=""
if [ "$SINGLE_AUDIO" = true ] && [ -n "$SELECTED_AUDIO_MAPPING" ]; then
    # Use the selected audio mapping from interactive selection
    map_audio="$SELECTED_AUDIO_MAPPING"
    print_status "Using selected audio mapping: $map_audio"
elif [ -n "$AUDIO_STREAMS" ]; then
    IFS=',' read -ra AUDIO_ARRAY <<< "$AUDIO_STREAMS"
    for audio in "${AUDIO_ARRAY[@]}"; do
        map_audio="$map_audio -map 0:a:$audio"
    done
else
    map_audio="-map 0:a?"
fi

# Map subtitles (all or selected)
map_subs=""
if [ -n "$SUBTITLE_STREAMS" ]; then
    IFS=',' read -ra SUB_ARRAY <<< "$SUBTITLE_STREAMS"
    for sub in "${SUB_ARRAY[@]}"; do
        map_subs="$map_subs -map 0:s:$sub"
    done
else
    # Determine the input file to probe for subtitles
    print_status "Probing subtitle streams in: $input_file"
    subtitle_streams_json=$(ffprobe -hide_banner -loglevel error -probesize 10000000 -analyzeduration 10000000 -show_streams -select_streams s -print_format json "$input_file" 2>/dev/null)
    subtitle_count=$(echo "$subtitle_streams_json" | jq '.streams | length')
    print_status "Found $subtitle_count subtitle streams"
    if [ "$subtitle_count" -gt 0 ]; then
        map_subs="-map 0:s?"
        print_status "Will map all subtitle streams"
    else
        print_warning "No subtitle streams found"
        map_subs=""
    fi
fi

# Add quality suffix to output filename
output_base="${OUTPUT_FILE%.mkv}"
output_with_quality="${output_base}_${QUALITY}.mkv"

# Build ffmpeg command
ffmpeg_cmd=$(build_ffmpeg_command "$input_file" "$output_with_quality" "$QUALITY" "$PRESERVE_AUDIO" "$map_audio" "$map_subs" "$METADATA_FILE" "$USE_FFMPEG_CONCAT")

if [ $? -ne 0 ]; then
    print_error "Failed to build ffmpeg command"
    exit 1
fi

# Extract metadata before conversion
metadata_output="${output_with_quality%.mkv}_metadata.json"
extract_dvd_metadata "$video_ts_path" "$metadata_output" "$TITLE_NUM"

# Run conversion
run_ffmpeg_conversion "$ffmpeg_cmd" "$output_with_quality" "$TITLE_NUM"

if [ $? -eq 0 ]; then
    print_success "Metadata file: $metadata_output"
    exit 0
else
    exit 1
fi
