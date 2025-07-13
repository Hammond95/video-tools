#!/bin/bash

# MKV Doctor - Diagnostic and Repair Tool for MKV Files
# Analyzes MKV files for common issues and provides repair options

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${PURPLE}[HEADER]${NC} $1"; }

# Function to show usage
show_usage() {
    echo "Usage: $0 <mkv_file> [options]"
    echo ""
    echo "Options:"
    echo "  -a, --analyze-only     Only analyze the file, don't attempt repairs"
    echo "  -r, --repair           Attempt to repair detected issues"
    echo "  -f, --force            Force repair even if issues are minor"
    echo "  -v, --verbose          Show detailed analysis information"
    echo "  -o, --output <file>    Specify output file for repaired version"
    echo "  -b, --backup           Create backup of original file before repair"
    echo "  -c, --check-only       Quick check for obvious issues"
    echo "  -d, --deep             Perform deep analysis (includes stress testing)"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 movie.mkv                    # Full analysis"
    echo "  $0 movie.mkv --analyze-only     # Analysis only"
    echo "  $0 movie.mkv --repair           # Analyze and repair"
    echo "  $0 movie.mkv --repair --backup  # Repair with backup"
    echo "  $0 movie.mkv --check-only       # Quick check"
    echo "  $0 movie.mkv --deep             # Deep analysis with stress testing"
    echo "  $0 movie.mkv --deep --verbose   # Deep analysis with detailed output"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    for dep in ffmpeg ffprobe mkvmerge mkvinfo; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install them:"
        echo "  macOS: brew install ffmpeg mkvtoolnix"
        echo "  Ubuntu/Debian: sudo apt install ffmpeg mkvtoolnix"
        echo "  CentOS/RHEL: sudo yum install ffmpeg mkvtoolnix"
        exit 1
    fi
}

# Function to validate input file
validate_input_file() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        print_error "File does not exist: $file"
        exit 1
    fi
    
    if [[ ! "$file" =~ \.mkv$ ]]; then
        print_warning "File does not have .mkv extension: $file"
        print_warning "This script is designed for MKV files"
    fi
    
    if [ ! -r "$file" ]; then
        print_error "File is not readable: $file"
        exit 1
    fi
    
    local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 1000000 ]; then
        print_warning "File is very small ($file_size bytes), may be corrupted"
    fi
}

# Function to get basic file information
get_basic_info() {
    local file="$1"
    local verbose="$2"
    
    print_header "Basic File Information"
    
    local file_size=$(stat -f%z "$file" 2>/dev/null || echo "0")
    local file_size_mb=$((file_size / 1024 / 1024))
    local file_size_gb=$((file_size / 1024 / 1024 / 1024))
    
    echo "  File: $file"
    echo "  Size: ${file_size_mb}MB (${file_size_gb}GB)"
    echo "  Permissions: $(ls -l "$file" | awk '{print $1}')"
    echo "  Modified: $(stat -f "%Sm" "$file" 2>/dev/null || echo "unknown")"
    
    if [ "$verbose" = true ]; then
        echo "  Inode: $(stat -f "%i" "$file" 2>/dev/null || echo "unknown")"
        echo "  Blocks: $(stat -f "%b" "$file" 2>/dev/null || echo "unknown")"
    fi
}

# Function to analyze MKV structure
analyze_mkv_structure() {
    local file="$1"
    local verbose="$2"
    
    print_header "MKV Structure Analysis"
    
    # Use mkvinfo for detailed MKV structure
    local mkvinfo_output=$(mkvinfo "$file" 2>/dev/null || echo "")
    
    if [ -z "$mkvinfo_output" ]; then
        print_error "Could not analyze MKV structure - file may be corrupted"
        return 1
    fi
    
    # Check for basic MKV elements
    local has_ebml=$(echo "$mkvinfo_output" | grep -c "EBML" || echo "0")
    local has_segment=$(echo "$mkvinfo_output" | grep -c "Segment" || echo "0")
    local has_tracks=$(echo "$mkvinfo_output" | grep -c "Tracks" || echo "0")
    local has_clusters=$(echo "$mkvinfo_output" | grep -c "Cluster" || echo "0")
    
    echo "  EBML Header: $([ "$has_ebml" -gt 0 ] && echo "✓ Present" || echo "✗ Missing")"
    echo "  Segment: $([ "$has_segment" -gt 0 ] && echo "✓ Present" || echo "✗ Missing")"
    echo "  Tracks: $([ "$has_tracks" -gt 0 ] && echo "✓ Present" || echo "✗ Missing")"
    echo "  Clusters: $([ "$has_clusters" -gt 0 ] && echo "✓ Present" || echo "✗ Missing")"
    
    if [ "$verbose" = true ]; then
        echo ""
        echo "  Detailed structure:"
        echo "$mkvinfo_output" | head -50 | sed 's/^/    /'
        if [ $(echo "$mkvinfo_output" | wc -l) -gt 50 ]; then
            echo "    ... (truncated)"
        fi
    fi
    
    # Check for structural issues
    local issues=()
    if [ "$has_ebml" -eq 0 ]; then issues+=("Missing EBML header"); fi
    if [ "$has_segment" -eq 0 ]; then issues+=("Missing segment"); fi
    if [ "$has_tracks" -eq 0 ]; then issues+=("Missing tracks"); fi
    if [ "$has_clusters" -eq 0 ]; then issues+=("Missing clusters"); fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        print_warning "Structural issues detected:"
        for issue in "${issues[@]}"; do
            echo "    - $issue"
        done
        return 1
    else
        print_success "MKV structure appears valid"
    fi
}

# Function to analyze streams
analyze_streams() {
    local file="$1"
    local verbose="$2"
    
    print_header "Stream Analysis"
    
    # Get stream information using ffprobe
    local stream_info=$(ffprobe -hide_banner -loglevel error -show_streams -print_format json "$file" 2>/dev/null)
    
    if [ -z "$stream_info" ]; then
        print_error "Could not analyze streams - file may be corrupted"
        return 1
    fi
    
    # Parse stream information
    local video_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "video")) | length')
    local audio_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "audio")) | length')
    local subtitle_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "subtitle")) | length')
    local attachment_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "attachment")) | length')
    
    echo "  Video streams: $video_count"
    echo "  Audio streams: $audio_count"
    echo "  Subtitle streams: $subtitle_count"
    echo "  Attachments: $attachment_count"
    
    # Analyze video streams
    if [ "$video_count" -gt 0 ]; then
        echo ""
        echo "  Video streams:"
        for i in $(seq 0 $((video_count - 1))); do
            local video_stream=$(echo "$stream_info" | jq ".streams | map(select(.codec_type == \"video\")) | .[$i]")
            local codec=$(echo "$video_stream" | jq -r '.codec_name // "unknown"')
            local width=$(echo "$video_stream" | jq -r '.width // "unknown"')
            local height=$(echo "$video_stream" | jq -r '.height // "unknown"')
            local duration=$(echo "$video_stream" | jq -r '.duration // "unknown"')
            local bit_rate=$(echo "$video_stream" | jq -r '.bit_rate // "unknown"')
            
            echo "    [$i] $codec ${width}x${height} (${duration}s, ${bit_rate}bps)"
            
            # Check for common video issues
            if [ "$codec" = "unknown" ]; then
                print_warning "    - Unknown video codec"
            fi
            if [ "$width" = "unknown" ] || [ "$height" = "unknown" ]; then
                print_warning "    - Missing resolution information"
            fi
        done
    fi
    
    # Analyze audio streams
    if [ "$audio_count" -gt 0 ]; then
        echo ""
        echo "  Audio streams:"
        for i in $(seq 0 $((audio_count - 1))); do
            local audio_stream=$(echo "$stream_info" | jq ".streams | map(select(.codec_type == \"audio\")) | .[$i]")
            local codec=$(echo "$audio_stream" | jq -r '.codec_name // "unknown"')
            local channels=$(echo "$audio_stream" | jq -r '.channels // "unknown"')
            local sample_rate=$(echo "$audio_stream" | jq -r '.sample_rate // "unknown"')
            local language=$(echo "$audio_stream" | jq -r '.tags.language // .tags.LANGUAGE // "unknown"')
            
            echo "    [$i] $codec ${channels}ch ${sample_rate}Hz ($language)"
            
            # Check for common audio issues
            if [ "$codec" = "unknown" ]; then
                print_warning "    - Unknown audio codec"
            fi
            if [ "$channels" = "0" ]; then
                print_warning "    - Zero channels detected"
            fi
        done
    fi
    
    # Check for stream issues
    local issues=()
    if [ "$video_count" -eq 0 ]; then issues+=("No video streams"); fi
    if [ "$audio_count" -eq 0 ]; then issues+=("No audio streams"); fi
    
    if [ ${#issues[@]} -gt 0 ]; then
        print_warning "Stream issues detected:"
        for issue in "${issues[@]}"; do
            echo "    - $issue"
        done
        return 1
    fi
}

# Function to check for corruption
check_corruption() {
    local file="$1"
    local verbose="$2"
    
    print_header "Corruption Check"
    
    # Check file integrity with ffmpeg
    print_status "Running integrity check (this may take a while)..."
    
    local integrity_output=$(ffmpeg -hide_banner -loglevel error -i "$file" -f null - 2>&1)
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_success "File integrity check passed"
        if [ "$verbose" = true ]; then
            echo "  No corruption detected"
        fi
    else
        print_error "File integrity check failed"
        if [ "$verbose" = true ]; then
            echo "  Error output:"
            echo "$integrity_output" | sed 's/^/    /'
        fi
        
        # Try to identify specific corruption issues
        local corruption_issues=()
        if echo "$integrity_output" | grep -q "Invalid data found"; then
            corruption_issues+=("Invalid data found in stream")
        fi
        if echo "$integrity_output" | grep -q "Error while decoding"; then
            corruption_issues+=("Decoding errors detected")
        fi
        if echo "$integrity_output" | grep -q "Invalid timestamp"; then
            corruption_issues+=("Invalid timestamps detected")
        fi
        if echo "$integrity_output" | grep -q "Packet too large"; then
            corruption_issues+=("Oversized packets detected")
        fi
        
        if [ ${#corruption_issues[@]} -gt 0 ]; then
            echo "  Specific issues:"
            for issue in "${corruption_issues[@]}"; do
                echo "    - $issue"
            done
        fi
        
        return 1
    fi
}

# Function to check audio/video sync
check_av_sync() {
    local file="$1"
    local verbose="$2"
    
    print_header "Audio/Video Sync Check"
    
    # Get stream information
    local stream_info=$(ffprobe -hide_banner -loglevel error -show_streams -print_format json "$file" 2>/dev/null)
    
    if [ -z "$stream_info" ]; then
        print_error "Could not analyze sync - file may be corrupted"
        return 1
    fi
    
    # Get video and audio start times
    local video_start=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "video")) | .[0].start_time // 0')
    local audio_start=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "audio")) | .[0].start_time // 0')
    
    # Calculate difference
    local sync_diff=$(echo "$video_start - $audio_start" | bc -l 2>/dev/null || echo "0")
    local sync_diff_abs=$(echo "$sync_diff" | sed 's/-//')
    
    echo "  Video start time: ${video_start}s"
    echo "  Audio start time: ${audio_start}s"
    echo "  Sync difference: ${sync_diff}s"
    
    # Check for sync issues
    if (( $(echo "$sync_diff_abs > 0.1" | bc -l) )); then
        print_warning "Audio/video sync issue detected"
        echo "  Difference is greater than 0.1 seconds"
        if (( $(echo "$sync_diff_abs > 1.0" | bc -l) )); then
            print_error "  Severe sync issue - difference is greater than 1 second"
            return 1
        fi
    else
        print_success "Audio/video sync appears normal"
    fi
}

# Function to attempt repair
attempt_repair() {
    local input_file="$1"
    local output_file="$2"
    local force="$3"
    
    print_header "Attempting Repair"
    
    if [ -z "$output_file" ]; then
        local base_name="${input_file%.mkv}"
        output_file="${base_name}_repaired.mkv"
    fi
    
    print_status "Repairing file: $input_file"
    print_status "Output file: $output_file"
    
    # Create backup if requested
    if [ "$BACKUP" = true ]; then
        local backup_file="${input_file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Creating backup: $backup_file"
        cp "$input_file" "$backup_file"
        print_success "Backup created: $backup_file"
    fi
    
    # Attempt repair using ffmpeg with error correction
    print_status "Running repair process..."
    
    local repair_cmd="ffmpeg -hide_banner -y -fflags +genpts -err_detect ignore_err -i \"$input_file\" -c copy -avoid_negative_ts make_zero \"$output_file\""
    
    if [ "$force" = true ]; then
        repair_cmd="ffmpeg -hide_banner -y -fflags +genpts -err_detect ignore_err -i \"$input_file\" -c copy -avoid_negative_ts make_zero -max_muxing_queue_size 1024 \"$output_file\""
    fi
    
    print_status "Command: $repair_cmd"
    
    # Run repair
    local repair_output=$(eval "$repair_cmd" 2>&1)
    local repair_exit_code=$?
    
    if [ $repair_exit_code -eq 0 ] && [ -f "$output_file" ] && [ -s "$output_file" ]; then
        print_success "Repair completed successfully"
        
        # Verify the repaired file
        print_status "Verifying repaired file..."
        local verify_output=$(ffmpeg -hide_banner -loglevel error -i "$output_file" -f null - 2>&1)
        local verify_exit_code=$?
        
        if [ $verify_exit_code -eq 0 ]; then
            print_success "Repaired file verification passed"
        else
            print_warning "Repaired file verification failed - some issues may remain"
        fi
        
        echo "  Original file: $input_file"
        echo "  Repaired file: $output_file"
        
        return 0
    else
        print_error "Repair failed"
        if [ "$VERBOSE" = true ]; then
            echo "  Error output:"
            echo "$repair_output" | sed 's/^/    /'
        fi
        return 1
    fi
}

# Function to perform deep stream analysis
deep_stream_analysis() {
    local file="$1"
    local verbose="$2"
    
    print_header "Deep Stream Analysis"
    
    # Get detailed stream information
    local stream_info=$(ffprobe -hide_banner -loglevel error -show_streams -show_packets -print_format json "$file" 2>/dev/null)
    
    if [ -z "$stream_info" ]; then
        print_error "Could not perform deep stream analysis"
        return 1
    fi
    
    local issues_found=0
    
    # Check for problematic codecs
    local video_streams=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "video"))')
    local audio_streams=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "audio"))')
    
    # Video stream deep analysis
    local video_count=$(echo "$video_streams" | jq 'length')
    if [ "$video_count" -gt 0 ]; then
        echo "  Video stream analysis:"
        for i in $(seq 0 $((video_count - 1))); do
            local video_stream=$(echo "$video_streams" | jq ".[$i]")
            local codec=$(echo "$video_stream" | jq -r '.codec_name // "unknown"')
            local profile=$(echo "$video_stream" | jq -r '.profile // "unknown"')
            local level=$(echo "$video_stream" | jq -r '.level // "unknown"')
            local pix_fmt=$(echo "$video_stream" | jq -r '.pix_fmt // "unknown"')
            local has_b_frames=$(echo "$video_stream" | jq -r '.has_b_frames // 0')
            local refs=$(echo "$video_stream" | jq -r '.refs // "unknown"')
            
            echo "    Stream $i: $codec (profile: $profile, level: $level)"
            echo "      Pixel format: $pix_fmt, B-frames: $has_b_frames, Refs: $refs"
            
            # Check for problematic video codec combinations
            if [ "$codec" = "h264" ] && [ "$profile" = "High 4:4:4" ]; then
                print_warning "    - High 4:4:4 profile can cause playback issues in some players"
                ((issues_found++))
            fi
            
            if [ "$codec" = "h264" ] && [ "$level" = "5.2" ]; then
                print_warning "    - H.264 Level 5.2 may not be supported by all players"
                ((issues_found++))
            fi
            
            if [ "$pix_fmt" = "unknown" ]; then
                print_warning "    - Unknown pixel format detected"
                ((issues_found++))
            fi
        done
    fi
    
    # Audio stream deep analysis
    local audio_count=$(echo "$audio_streams" | jq 'length')
    if [ "$audio_count" -gt 0 ]; then
        echo ""
        echo "  Audio stream analysis:"
        for i in $(seq 0 $((audio_count - 1))); do
            local audio_stream=$(echo "$audio_streams" | jq ".[$i]")
            local codec=$(echo "$audio_stream" | jq -r '.codec_name // "unknown"')
            local channels=$(echo "$audio_stream" | jq -r '.channels // 0')
            local sample_rate=$(echo "$audio_stream" | jq -r '.sample_rate // 0')
            local bit_rate=$(echo "$audio_stream" | jq -r '.bit_rate // 0')
            local layout=$(echo "$audio_stream" | jq -r '.channel_layout // "unknown"')
            
            echo "    Stream $i: $codec ${channels}ch ${sample_rate}Hz"
            echo "      Bit rate: ${bit_rate}bps, Layout: $layout"
            
            # Check for problematic audio configurations
            if [ "$channels" -gt 8 ]; then
                print_warning "    - High channel count ($channels) may cause playback issues"
                ((issues_found++))
            fi
            
            if [ "$sample_rate" -gt 96000 ]; then
                print_warning "    - High sample rate (${sample_rate}Hz) may not be supported"
                ((issues_found++))
            fi
            
            if [ "$codec" = "dts" ] && [ "$channels" -gt 6 ]; then
                print_warning "    - DTS with more than 6 channels may cause issues"
                ((issues_found++))
            fi
        done
    fi
    
    if [ $issues_found -gt 0 ]; then
        print_warning "Deep analysis found $issues_found potential issue(s)"
        return 1
    else
        print_success "Deep stream analysis passed"
    fi
}

# Function to check for timing issues
check_timing_issues() {
    local file="$1"
    local verbose="$2"
    
    print_header "Timing Analysis"
    
    # Get packet information for timing analysis
    local packet_info=$(ffprobe -hide_banner -loglevel error -show_packets -print_format json "$file" 2>/dev/null)
    
    if [ -z "$packet_info" ]; then
        print_error "Could not analyze timing information"
        return 1
    fi
    
    local issues_found=0
    
    # Analyze packet timing
    local packets=$(echo "$packet_info" | jq '.packets')
    local packet_count=$(echo "$packets" | jq 'length')
    
    if [ "$packet_count" -eq 0 ]; then
        print_error "No packets found in file"
        return 1
    fi
    
    echo "  Total packets: $packet_count"
    
    # Check for negative timestamps
    local negative_ts_count=$(echo "$packets" | jq 'map(select(.pts < 0)) | length')
    if [ "$negative_ts_count" -gt 0 ]; then
        print_warning "Found $negative_ts_count packets with negative timestamps"
        ((issues_found++))
    fi
    
    # Check for large timestamp gaps
    local large_gaps=0
    local prev_pts=0
    local first_packet=true
    
    while IFS= read -r pts; do
        if [ "$first_packet" = true ]; then
            prev_pts="$pts"
            first_packet=false
            continue
        fi
        
        if [ "$pts" != "null" ] && [ "$prev_pts" != "null" ]; then
            local gap=$(echo "$pts - $prev_pts" | bc -l 2>/dev/null || echo "0")
            local gap_abs=$(echo "$gap" | sed 's/-//')
            
            if (( $(echo "$gap_abs > 10.0" | bc -l) )); then
                ((large_gaps++))
            fi
        fi
        prev_pts="$pts"
    done < <(echo "$packets" | jq -r '.[].pts')
    
    if [ "$large_gaps" -gt 0 ]; then
        print_warning "Found $large_gaps large timestamp gaps (>10s)"
        ((issues_found++))
    fi
    
    # Check for duplicate timestamps
    local duplicate_ts=$(echo "$packets" | jq -r '.[].pts' | sort | uniq -d | wc -l)
    if [ "$duplicate_ts" -gt 0 ]; then
        print_warning "Found $duplicate_ts duplicate timestamps"
        ((issues_found++))
    fi
    
    if [ $issues_found -gt 0 ]; then
        print_warning "Timing analysis found $issues_found issue(s)"
        return 1
    else
        print_success "Timing analysis passed"
    fi
}

# Function to check for container issues
check_container_issues() {
    local file="$1"
    local verbose="$2"
    
    print_header "Container Analysis"
    
    # Use mkvmerge to analyze container
    local mkvmerge_info=$(mkvmerge -i "$file" 2>&1)
    local mkvmerge_exit=$?
    
    if [ $mkvmerge_exit -ne 0 ]; then
        print_error "mkvmerge analysis failed"
        if [ "$verbose" = true ]; then
            echo "  Error output:"
            echo "$mkvmerge_info" | sed 's/^/    /'
        fi
        return 1
    fi
    
    local issues_found=0
    
    # Check for specific container issues
    if echo "$mkvmerge_info" | grep -q "Warning:"; then
        print_warning "mkvmerge warnings detected:"
        echo "$mkvmerge_info" | grep "Warning:" | sed 's/^/    /'
        ((issues_found++))
    fi
    
    if echo "$mkvmerge_info" | grep -q "Error:"; then
        print_error "mkvmerge errors detected:"
        echo "$mkvmerge_info" | grep "Error:" | sed 's/^/    /'
        ((issues_found++))
    fi
    
    # Check for specific problematic patterns
    if echo "$mkvmerge_info" | grep -q "no video track"; then
        print_error "No video track found in container"
        ((issues_found++))
    fi
    
    if echo "$mkvmerge_info" | grep -q "no audio track"; then
        print_error "No audio track found in container"
        ((issues_found++))
    fi
    
    # Check for unusual track types
    local track_types=$(echo "$mkvmerge_info" | grep "Track ID" | awk '{print $4}')
    for track_type in $track_types; do
        if [ "$track_type" != "video" ] && [ "$track_type" != "audio" ] && [ "$track_type" != "subtitles" ]; then
            print_warning "Unusual track type found: $track_type"
            ((issues_found++))
        fi
    done
    
    if [ $issues_found -gt 0 ]; then
        print_warning "Container analysis found $issues_found issue(s)"
        return 1
    else
        print_success "Container analysis passed"
    fi
}

# Function to check for playback compatibility issues
check_playback_compatibility() {
    local file="$1"
    local verbose="$2"
    
    print_header "Playback Compatibility Analysis"
    
    # Get format information
    local format_info=$(ffprobe -hide_banner -loglevel error -show_format -print_format json "$file" 2>/dev/null)
    
    if [ -z "$format_info" ]; then
        print_error "Could not analyze format information"
        return 1
    fi
    
    local issues_found=0
    
    # Check format duration
    local duration=$(echo "$format_info" | jq -r '.format.duration // "unknown"')
    if [ "$duration" != "unknown" ]; then
        local duration_hours=$(echo "$duration / 3600" | bc -l 2>/dev/null || echo "0")
        echo "  Duration: ${duration_hours}h (${duration}s)"
        
        if (( $(echo "$duration_hours > 4" | bc -l) )); then
            print_warning "Very long duration (${duration_hours}h) may cause playback issues"
            ((issues_found++))
        fi
    fi
    
    # Check file size
    local file_size=$(echo "$format_info" | jq -r '.format.size // "unknown"')
    if [ "$file_size" != "unknown" ]; then
        local file_size_gb=$(echo "$file_size / 1024 / 1024 / 1024" | bc -l 2>/dev/null || echo "0")
        echo "  File size: ${file_size_gb}GB"
        
        if (( $(echo "$file_size_gb > 10" | bc -l) )); then
            print_warning "Very large file (${file_size_gb}GB) may cause playback issues"
            ((issues_found++))
        fi
    fi
    
    # Check for problematic tags
    local tags=$(echo "$format_info" | jq -r '.format.tags // {}')
    if [ "$tags" != "{}" ]; then
        local title=$(echo "$tags" | jq -r '.title // "unknown"')
        local artist=$(echo "$tags" | jq -r '.artist // "unknown"')
        
        if [ "$title" != "unknown" ] && [ ${#title} -gt 100 ]; then
            print_warning "Very long title tag (${#title} chars) may cause issues"
            ((issues_found++))
        fi
        
        if [ "$artist" != "unknown" ] && [ ${#artist} -gt 100 ]; then
            print_warning "Very long artist tag (${#artist} chars) may cause issues"
            ((issues_found++))
        fi
    fi
    
    # Check for specific problematic formats
    local stream_info=$(ffprobe -hide_banner -loglevel error -show_streams -print_format json "$file" 2>/dev/null)
    local video_codecs=$(echo "$stream_info" | jq -r '.streams | map(select(.codec_type == "video")) | .[].codec_name // "unknown"')
    local audio_codecs=$(echo "$stream_info" | jq -r '.streams | map(select(.codec_type == "audio")) | .[].codec_name // "unknown"')
    
    # Check for problematic video codecs
    for codec in $video_codecs; do
        case "$codec" in
            "hevc"|"h265")
                print_warning "HEVC/H.265 codec may not be supported by all players"
                ((issues_found++))
                ;;
            "vp9")
                print_warning "VP9 codec may not be supported by all players"
                ((issues_found++))
                ;;
            "av1")
                print_warning "AV1 codec may not be supported by all players"
                ((issues_found++))
                ;;
        esac
    done
    
    # Check for problematic audio codecs
    for codec in $audio_codecs; do
        case "$codec" in
            "opus")
                print_warning "Opus audio codec may not be supported by all players"
                ((issues_found++))
                ;;
            "flac")
                print_warning "FLAC audio codec may not be supported by all players"
                ((issues_found++))
                ;;
        esac
    done
    
    if [ $issues_found -gt 0 ]; then
        print_warning "Compatibility analysis found $issues_found potential issue(s)"
        return 1
    else
        print_success "Playback compatibility analysis passed"
    fi
}

# Function to perform stress test
stress_test() {
    local file="$1"
    local verbose="$2"
    
    print_header "Stress Test Analysis"
    
    print_status "Performing playback stress test (this may take a while)..."
    
    # Try to seek to different positions to test playback stability
    local duration=$(ffprobe -hide_banner -loglevel error -show_format -print_format json "$file" 2>/dev/null | jq -r '.format.duration // "0"')
    
    if [ "$duration" = "0" ] || [ "$duration" = "null" ]; then
        print_warning "Could not determine duration for stress test"
        return 0
    fi
    
    local duration_sec=$(echo "$duration" | bc -l 2>/dev/null || echo "0")
    local issues_found=0
    
    # Test seeking to different positions
    local test_positions=("0" "10" "30" "60" "120" "300")
    
    for pos in "${test_positions[@]}"; do
        if (( $(echo "$pos < $duration_sec" | bc -l) )); then
            print_status "Testing seek to ${pos}s..."
            
            local seek_output=$(ffmpeg -hide_banner -loglevel error -ss "$pos" -i "$file" -t 5 -f null - 2>&1)
            local seek_exit=$?
            
            if [ $seek_exit -ne 0 ]; then
                print_warning "Seek to ${pos}s failed"
                if [ "$verbose" = true ]; then
                    echo "  Error: $seek_output"
                fi
                ((issues_found++))
            fi
        fi
    done
    
    # Test end of file
    local end_pos=$(echo "$duration_sec - 30" | bc -l 2>/dev/null || echo "0")
    if (( $(echo "$end_pos > 0" | bc -l) )); then
        print_status "Testing seek to end of file..."
        
        local end_seek_output=$(ffmpeg -hide_banner -loglevel error -ss "$end_pos" -i "$file" -t 30 -f null - 2>&1)
        local end_seek_exit=$?
        
        if [ $end_seek_exit -ne 0 ]; then
            print_warning "Seek to end of file failed"
            if [ "$verbose" = true ]; then
                echo "  Error: $end_seek_output"
            fi
            ((issues_found++))
        fi
    fi
    
    if [ $issues_found -gt 0 ]; then
        print_warning "Stress test found $issues_found issue(s)"
        return 1
    else
        print_success "Stress test passed"
    fi
}

# Function to perform quick check
quick_check() {
    local file="$1"
    
    print_header "Quick Check"
    
    # Basic file check
    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        print_error "File is not accessible"
        return 1
    fi
    
    # Check if it's a valid MKV
    local mkvinfo_output=$(mkvinfo "$file" 2>/dev/null | head -10)
    if [ -z "$mkvinfo_output" ]; then
        print_error "Not a valid MKV file"
        return 1
    fi
    
    # Quick stream check
    local stream_info=$(ffprobe -hide_banner -loglevel error -show_streams -print_format json "$file" 2>/dev/null)
    if [ -z "$stream_info" ]; then
        print_error "Cannot read stream information"
        return 1
    fi
    
    local video_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "video")) | length')
    local audio_count=$(echo "$stream_info" | jq '.streams | map(select(.codec_type == "audio")) | length')
    
    echo "  Video streams: $video_count"
    echo "  Audio streams: $audio_count"
    
    if [ "$video_count" -eq 0 ] || [ "$audio_count" -eq 0 ]; then
        print_warning "Missing video or audio streams"
        return 1
    fi
    
    print_success "File appears to be a valid MKV"
    return 0
}

# Main function
main() {
    local input_file=""
    local analyze_only=false
    local repair=false
    local force=false
    local verbose=false
    local output_file=""
    local backup=false
    local check_only=false
    local deep_analysis=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--analyze-only)
                analyze_only=true
                shift
                ;;
            -r|--repair)
                repair=true
                shift
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -b|--backup)
                backup=true
                shift
                ;;
            -c|--check-only)
                check_only=true
                shift
                ;;
            -d|--deep)
                deep_analysis=true
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
                if [ -z "$input_file" ]; then
                    input_file="$1"
                else
                    print_error "Too many arguments"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Validate input
    if [ -z "$input_file" ]; then
        print_error "No input file specified"
        show_usage
        exit 1
    fi
    
    # Check dependencies
    check_dependencies
    
    # Validate input file
    validate_input_file "$input_file"
    
    # Set global variables
    VERBOSE="$verbose"
    BACKUP="$backup"
    
    # Perform quick check if requested
    if [ "$check_only" = true ]; then
        quick_check "$input_file"
        exit $?
    fi

    # Perform deep analysis if requested
    if [ "$deep_analysis" = true ]; then
        print_header "Starting Deep Analysis (with Stress Test)"
        echo "File: $input_file"
        echo ""

        local issues_found=0

        # Basic information
        get_basic_info "$input_file" "$verbose"
        echo ""

        # MKV structure analysis
        if ! analyze_mkv_structure "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Stream analysis
        if ! analyze_streams "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Corruption check
        if ! check_corruption "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Audio/video sync check
        if ! check_av_sync "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Deep stream analysis
        if ! deep_stream_analysis "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Timing analysis
        if ! check_timing_issues "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Container analysis
        if ! check_container_issues "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Compatibility analysis
        if ! check_playback_compatibility "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Stress test
        if ! stress_test "$input_file" "$verbose"; then
            ((issues_found++))
        fi
        echo ""

        # Summary
        print_header "Analysis Summary"
        if [ $issues_found -eq 0 ]; then
            print_success "No issues detected - file appears to be healthy"
        else
            print_warning "$issues_found issue(s) detected"
        fi
        exit $issues_found
    fi
    
    # Perform analysis
    print_header "Starting MKV Analysis"
    echo "File: $input_file"
    echo ""
    
    local issues_found=0
    
    # Basic information
    get_basic_info "$input_file" "$verbose"
    echo ""
    
    # MKV structure analysis
    if ! analyze_mkv_structure "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Stream analysis
    if ! analyze_streams "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Corruption check
    if ! check_corruption "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Audio/video sync check
    if ! check_av_sync "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Deep stream analysis
    if ! deep_stream_analysis "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Timing analysis
    if ! check_timing_issues "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Container analysis
    if ! check_container_issues "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Compatibility analysis
    if ! check_playback_compatibility "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Stress test
    if ! stress_test "$input_file" "$verbose"; then
        ((issues_found++))
    fi
    echo ""
    
    # Summary
    print_header "Analysis Summary"
    if [ $issues_found -eq 0 ]; then
        print_success "No issues detected - file appears to be healthy"
    else
        print_warning "$issues_found issue(s) detected"
    fi
    
    # Attempt repair if requested
    if [ "$repair" = true ] && [ $issues_found -gt 0 ]; then
        echo ""
        if [ "$analyze_only" = true ]; then
            print_warning "Repair requested but analyze-only mode is enabled"
        else
            attempt_repair "$input_file" "$output_file" "$force"
        fi
    elif [ "$repair" = true ] && [ $issues_found -eq 0 ]; then
        echo ""
        print_warning "No issues detected - repair not necessary"
    fi
    
    exit $issues_found
}

# Run main function with all arguments
main "$@" 