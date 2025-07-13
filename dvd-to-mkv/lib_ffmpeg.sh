#!/bin/bash

# FFmpeg operations library for dvd-to-mkv.sh
# Handles all ffmpeg-related operations including audio/subtitle selection,
# concatenation, command building, and conversion

# Global variable for selected audio mapping
SELECTED_AUDIO_MAPPING=""

# Function to select a single audio track interactively
select_single_audio() {
    local input_file="$1"
    
    if [ ! -f "$input_file" ]; then
        print_error "Input file does not exist: $input_file"
        return 1
    fi
    
    print_status "Analyzing audio streams in: $input_file"
    
    # Get audio stream information
    local audio_info=$(ffprobe -hide_banner -loglevel error -select_streams a -show_streams -print_format json "$input_file" 2>/dev/null)
    
    if [ -z "$audio_info" ]; then
        print_error "Could not analyze audio streams"
        return 1
    fi
    
    # Parse audio streams
    local audio_streams=()
    local stream_count=$(echo "$audio_info" | jq '.streams | length')
    
    if [ "$stream_count" -eq 0 ]; then
        print_error "No audio streams found"
        return 1
    fi
    
    print_status "Found $stream_count audio stream(s):"
    echo ""
    
    # Display audio streams with detailed information
    for i in $(seq 0 $((stream_count - 1))); do
        local stream=$(echo "$audio_info" | jq ".streams[$i]")
        local codec=$(echo "$stream" | jq -r '.codec_name // "unknown"')
        local language=$(echo "$stream" | jq -r '.tags.language // .tags.LANGUAGE // "unknown"')
        local channels=$(echo "$stream" | jq -r '.channels // 0')
        local sample_rate=$(echo "$stream" | jq -r '.sample_rate // 0')
        local bit_rate=$(echo "$stream" | jq -r '.bit_rate // 0')
        
        # Check if stream appears corrupted (0 channels and 0 sample rate)
        local is_corrupted=false
        if [ "$channels" -eq 0 ] && [ "$sample_rate" -eq 0 ]; then
            is_corrupted=true
        fi
        
        # Format bit rate for display
        local bit_rate_display=""
        if [ "$bit_rate" -gt 0 ]; then
            if [ "$bit_rate" -gt 1000000 ]; then
                bit_rate_display=" ($((bit_rate / 1000))kbps)"
            else
                bit_rate_display=" ($bit_rate bps)"
            fi
        fi
        
        # Format channel info
        local channel_display=""
        if [ "$channels" -gt 0 ]; then
            case "$channels" in
                1) channel_display=" (mono)" ;;
                2) channel_display=" (stereo)" ;;
                *) channel_display=" (${channels}ch)" ;;
            esac
        fi
        
        # Mark corrupted streams instead of skipping
        if [ "$is_corrupted" = true ]; then
            echo "  [$i] [CORRUPTED] $codec - $language$channel_display$bit_rate_display"
            echo "      ⚠️  Stream appears corrupted (0 channels, 0 sample rate) - may be valid multichannel stream"
        else
            echo "  [$i] $codec - $language$channel_display$bit_rate_display"
        fi
        
        audio_streams+=("$i")
    done
    
    echo ""
    print_status "Select audio track (0-$((stream_count - 1))) or 'q' to quit:"
    
    # Single prompt with 30s timeout
    local selection=""
    echo -n "Selection (30s timeout): "
    if ! read -t 30 selection; then
        print_error "Selection timeout after 30s"
        return 1
    fi
    
    # Validate selection
    if [ "$selection" = "q" ] || [ "$selection" = "Q" ]; then
        print_status "Selection cancelled"
        return 1
    fi
    
    if ! [[ "$selection" =~ ^[0-9]+$ ]]; then
        print_error "Invalid selection: $selection"
        return 1
    fi
    
    if [ "$selection" -lt 0 ] || [ "$selection" -ge "$stream_count" ]; then
        print_error "Invalid selection: $selection (valid range: 0-$((stream_count - 1)))"
        return 1
    fi
    
    # Set the selected audio mapping
    SELECTED_AUDIO_MAPPING="-map 0:a:$selection"
    print_success "Selected audio track $selection"
    
    return 0
}

# Function to validate subtitle streams
validate_subtitle_streams() {
    local video_ts_path="$1"
    local subtitle_streams="$2"
    local title_num="$3"
    
    if [ -z "$subtitle_streams" ]; then
        return 0
    fi
    
    print_status "Validating subtitle streams: $subtitle_streams"
    
    # Get subtitle stream count for the title
    local title_num_padded=$(printf '%02d' "$title_num")
    local vob_file=$(find "$video_ts_path" -iname "VTS_${title_num_padded}_1.VOB" 2>/dev/null | head -1)
    
    if [ -z "$vob_file" ]; then
        print_error "Could not find VOB file for title $title_num"
        return 1
    fi
    
    local subtitle_count=$(ffprobe -hide_banner -loglevel error -select_streams s -show_streams -print_format json "$vob_file" 2>/dev/null | jq '.streams | length')
    
    IFS=',' read -ra SUB_ARRAY <<< "$subtitle_streams"
    for sub in "${SUB_ARRAY[@]}"; do
        if [ "$sub" -ge "$subtitle_count" ]; then
            print_error "Invalid subtitle stream: $sub (max: $((subtitle_count - 1)))"
            return 1
        fi
    done
    
    print_success "Subtitle streams validated"
}

# Function to validate audio streams
validate_audio_streams() {
    local video_ts_path="$1"
    local audio_streams="$2"
    local title_num="$3"
    
    if [ -z "$audio_streams" ]; then
        return 0
    fi
    
    print_status "Validating audio streams: $audio_streams"
    
    # Get audio stream count for the title
    local title_num_padded=$(printf '%02d' "$title_num")
    local vob_file=$(find "$video_ts_path" -iname "VTS_${title_num_padded}_1.VOB" 2>/dev/null | head -1)
    
    if [ -z "$vob_file" ]; then
        print_error "Could not find VOB file for title $title_num"
        return 1
    fi
    
    local audio_count=$(ffprobe -hide_banner -loglevel error -select_streams a -show_streams -print_format json "$vob_file" 2>/dev/null | jq '.streams | length')
    
    IFS=',' read -ra AUDIO_ARRAY <<< "$audio_streams"
    for audio in "${AUDIO_ARRAY[@]}"; do
        if [ "$audio" -ge "$audio_count" ]; then
            print_error "Invalid audio stream: $audio (max: $((audio_count - 1)))"
            return 1
        fi
    done
    
    print_success "Audio streams validated"
}

# Function to get stream information
get_stream_info() {
    local video_ts_path="$1"
    local title_num="$2"
    
    local title_num_padded=$(printf '%02d' "$title_num")
    local vob_file=$(find "$video_ts_path" -iname "VTS_${title_num_padded}_1.VOB" 2>/dev/null | head -1)
    
    if [ -z "$vob_file" ]; then
        print_error "Could not find VOB file for title $title_num"
        return 1
    fi
    
    print_status "Stream information for title $title_num:"
    
    # Get all stream information
    local stream_info=$(ffprobe -hide_banner -loglevel error -show_streams -print_format json "$vob_file" 2>/dev/null)
    
    if [ -z "$stream_info" ]; then
        print_error "Could not get stream information"
        return 1
    fi
    
    # Parse and display streams
    local video_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "video")) | length')
    local audio_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "audio")) | length')
    local subtitle_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "subtitle")) | length')
    
    echo "  Video streams: $video_count"
    echo "  Audio streams: $audio_count"
    echo "  Subtitle streams: $subtitle_count"
    
    # Show detailed audio stream info
    if [ "$audio_count" -gt 0 ]; then
        echo ""
        echo "  Audio streams:"
        for i in $(seq 0 $((audio_count - 1))); do
            local audio_stream=$(echo "$stream_info" | jq ".streams | map(select(.codec_type == \"audio\")) | .[$i]")
            local codec=$(echo "$audio_stream" | jq -r '.codec_name // "unknown"')
            local language=$(echo "$audio_stream" | jq -r '.tags.language // .tags.LANGUAGE // "unknown"')
            local channels=$(echo "$audio_stream" | jq -r '.channels // 0')
            local sample_rate=$(echo "$audio_stream" | jq -r '.sample_rate // 0')
            
            local channel_display=""
            if [ "$channels" -gt 0 ]; then
                case "$channels" in
                    1) channel_display=" (mono)" ;;
                    2) channel_display=" (stereo)" ;;
                    *) channel_display=" (${channels}ch)" ;;
                esac
            fi
            
            echo "    [$i] $codec - $language$channel_display"
        done
    fi
    
    # Show detailed subtitle stream info
    if [ "$subtitle_count" -gt 0 ]; then
        echo ""
        echo "  Subtitle streams:"
        for i in $(seq 0 $((subtitle_count - 1))); do
            local subtitle_stream=$(echo "$stream_info" | jq ".streams | map(select(.codec_type == \"subtitle\")) | .[$i]")
            local codec=$(echo "$subtitle_stream" | jq -r '.codec_name // "unknown"')
            local language=$(echo "$subtitle_stream" | jq -r '.tags.language // .tags.LANGUAGE // "unknown"')
            
            echo "    [$i] $codec - $language"
        done
    fi
}

# Function to build ffmpeg command
build_ffmpeg_command() {
    local input_file="$1"
    local output_file="$2"
    local quality="$3"
    local preserve_audio="$4"
    local audio_mapping="$5"
    local subtitle_mapping="$6"
    local metadata_file="$7"
    local use_ffmpeg_concat="$8"
    
    # Start with base ffmpeg command
    local ffmpeg_cmd="ffmpeg -hide_banner -y -fflags +genpts"
    
    # Add input file
    ffmpeg_cmd="$ffmpeg_cmd -i \"$input_file\""
    
    # Add stream mappings
    ffmpeg_cmd="$ffmpeg_cmd $subtitle_mapping $audio_mapping -map 0:v:0"
    
    # Add codec settings based on quality
    case "$quality" in
        "copy")
            if [ "$preserve_audio" = true ]; then
                ffmpeg_cmd="$ffmpeg_cmd -c:v copy -c:a copy -c:s copy -avoid_negative_ts make_zero"
            else
                ffmpeg_cmd="$ffmpeg_cmd -c:v copy -c:a aac -c:s copy -avoid_negative_ts make_zero"
            fi
            ;;
        "h264")
            if [ "$preserve_audio" = true ]; then
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 18 -preset slow -c:a copy -c:s copy"
            else
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 18 -preset slow -c:a aac -c:s copy"
            fi
            ;;
        "h265")
            if [ "$preserve_audio" = true ]; then
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx265 -crf 20 -preset slow -threads 0 -thread_type frame -c:a copy -c:s copy"
            else
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx265 -crf 20 -preset slow -threads 0 -thread_type frame -c:a aac -c:s copy"
            fi
            ;;
        "h265fast")
            if [ "$preserve_audio" = true ]; then
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx265 -crf 24 -preset fast -threads 0 -thread_type frame -c:a copy -c:s copy"
            else
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx265 -crf 24 -preset fast -threads 0 -thread_type frame -c:a aac -c:s copy"
            fi
            ;;
        "h265hw")
            if [ "$preserve_audio" = true ]; then
                ffmpeg_cmd="$ffmpeg_cmd -c:v hevc_videotoolbox -b:v 5000k -c:a copy -c:s copy"
            else
                ffmpeg_cmd="$ffmpeg_cmd -c:v hevc_videotoolbox -b:v 5000k -c:a aac -c:s copy"
            fi
            ;;
        "repair")
            if [ "$preserve_audio" = true ]; then
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 23 -preset medium -c:a copy -c:s copy -fflags +genpts -err_detect ignore_err"
            else
                ffmpeg_cmd="$ffmpeg_cmd -c:v libx264 -crf 23 -preset medium -c:a aac -c:s copy -fflags +genpts -err_detect ignore_err"
            fi
            ;;
        *)
            print_error "Unknown quality setting: $quality"
            return 1
            ;;
    esac
    
    # Add metadata
    if [ -n "$metadata_file" ] && [ -f "$metadata_file" ]; then
        local title=$(jq -r '.title // "DVD Movie"' "$metadata_file" 2>/dev/null)
        local author=$(jq -r '.author // "DVD Backup"' "$metadata_file" 2>/dev/null)
        local comment=$(jq -r '.comment // "Extracted using dvd-to-mkv.sh"' "$metadata_file" 2>/dev/null)
        
        ffmpeg_cmd="$ffmpeg_cmd -metadata title=\"$title\" -metadata author=\"$author\" -metadata comment=\"$comment\""
    else
        local default_title=$(basename "$output_file" .mkv)
        ffmpeg_cmd="$ffmpeg_cmd -metadata title=\"$default_title\" -metadata author=\"DVD Backup\" -metadata comment=\"Extracted using dvd-to-mkv.sh\""
    fi
    
    # Add output options
    ffmpeg_cmd="$ffmpeg_cmd -muxpreload 0 -muxdelay 0"
    
    # Add output file
    ffmpeg_cmd="$ffmpeg_cmd \"$output_file\""
    
    echo "$ffmpeg_cmd"
}

# Function to concatenate VOB files
concatenate_vob_files() {
    local video_ts_path="$1"
    local title_num="$2"
    local use_ffmpeg_concat="$3"
    
    local title_num_padded=$(printf '%02d' "$title_num")
    local process_id=$$
    local timestamp=$(date +%s)
    local unique_id="${process_id}_${timestamp}"
    local concatenated_vob="/tmp/concatenated_${title_num}_${unique_id}.vob"
    
    # Find all VOB parts for this title
    local vob_parts=()
    while IFS= read -r -d '' file; do
        vob_parts+=("$file")
    done < <(find "$video_ts_path" -iname "VTS_${title_num_padded}_*.VOB" -print0 2>/dev/null | sort -z)
    
    if [ ${#vob_parts[@]} -eq 0 ]; then
        print_error "No VOB files found for title $title_num" >&2
        return 1
    fi
    
    if [ ${#vob_parts[@]} -eq 1 ]; then
        # Single VOB file, no concatenation needed
        echo "${vob_parts[0]}"
        return 0
    fi
    
    print_status "Found ${#vob_parts[@]} VOB parts, concatenating..." >&2
    
    if [ "$use_ffmpeg_concat" = true ]; then
        # Use ffmpeg concat demuxer
        local concat_file="/tmp/concat_${title_num}_${unique_id}.txt"
        
        print_status "Creating concat file: $concat_file" >&2
        
        # Create the concat file with all VOB parts
        > "$concat_file"  # Clear/create the file
        for vob_part in "${vob_parts[@]}"; do
            echo "file '$vob_part'" >> "$concat_file"
        done
        
        print_status "Concatenating VOB files using ffmpeg concat demuxer..." >&2
        
        # Use ffmpeg concat demuxer for proper stream handling
        ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i "$concat_file" -c copy -avoid_negative_ts make_zero "$concatenated_vob"
        
        if [ $? -eq 0 ] && [ -s "$concatenated_vob" ]; then
            print_success "VOB concatenation successful using ffmpeg concat demuxer" >&2
            rm -f "$concat_file"
            echo "$concatenated_vob"
            return 0
        else
            print_error "Failed to concatenate VOB files using ffmpeg" >&2
            print_error "Falling back to simple cat concatenation..." >&2
            rm -f "$concat_file"
        fi
    fi
    
    # Fallback to simple cat concatenation
    print_status "Using cat concatenation..." >&2
    cat "${vob_parts[@]}" > "$concatenated_vob"
    
    if [ $? -eq 0 ] && [ -s "$concatenated_vob" ]; then
        print_success "VOB concatenation successful (cat method)" >&2
        echo "$concatenated_vob"
        return 0
    else
        print_error "Failed to concatenate VOB files" >&2
        return 1
    fi
}

# Function to run ffmpeg conversion
run_ffmpeg_conversion() {
    local ffmpeg_cmd="$1"
    local output_file="$2"
    local title_num="$3"
    local input_file="$4"
    
    print_status "Starting conversion..."
    print_status "Command: $ffmpeg_cmd"
    echo ""
    
    # Run ffmpeg and capture exit code
    eval "$ffmpeg_cmd"
    local ffmpeg_exit_code=$?
    
    # Check if output file was created and has reasonable size
    if [ -f "$output_file" ] && [ -s "$output_file" ]; then
        local file_size=$(stat -f%z "$output_file" 2>/dev/null || echo "0")
        if [ "$file_size" -gt 1000000 ]; then  # At least 1MB
            print_success "Conversion completed successfully!"
            print_success "Output file: $output_file (size: $(ls -lh "$output_file" | awk '{print $5}'))"
            
            if [ $ffmpeg_exit_code -ne 0 ]; then
                print_warning "ffmpeg exited with code $ffmpeg_exit_code, but output file was created successfully"
                print_warning "This may indicate some warnings during conversion, but the file should be playable"
            fi
            
            # Clean up concatenated VOB file if it was created (and is a temporary file)
            if [ -n "$input_file" ] && [[ "$input_file" == /tmp/concatenated_* ]]; then
                if [ -f "$input_file" ]; then
                    rm "$input_file"
                    print_status "Cleaned up temporary concatenated VOB file: $input_file"
                fi
            fi
            
            # Show file info
            print_status "File information:"
            ffprobe -hide_banner -loglevel error -print_format json -show_format -show_streams "$output_file" 2>/dev/null | \
                jq -r '.format.duration as $dur | .streams[] | "\(.codec_type): \(.codec_name) (\(.language // "unknown"))"' 2>/dev/null || \
                print_warning "Could not retrieve output file information"
            
            return 0
        else
            print_error "Conversion failed: Output file is too small ($file_size bytes)"
            # Clean up concatenated VOB file if it was created (and is a temporary file)
            if [ -n "$input_file" ] && [[ "$input_file" == /tmp/concatenated_* ]]; then
                if [ -f "$input_file" ]; then
                    rm "$input_file"
                    print_status "Cleaned up temporary concatenated VOB file: $input_file"
                fi
            fi
            return 1
        fi
    else
        print_error "Conversion failed: Output file was not created"
        # Clean up concatenated VOB file if it was created (and is a temporary file)
        if [ -n "$input_file" ] && [[ "$input_file" == /tmp/concatenated_* ]]; then
            if [ -f "$input_file" ]; then
                rm "$input_file"
                print_status "Cleaned up temporary concatenated VOB file: $input_file"
            fi
        fi
        return 1
    fi
} 