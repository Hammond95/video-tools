#!/bin/bash

# Function to show usage
show_usage() {
    echo "Usage: $0 <path_to_VIDEO_TS_folder> <output_file.mkv> [options]"
    echo ""
    echo "Options:"
    echo "  -t, --title <number>     DVD title number to extract (default: auto-detect)"
    echo "  -s, --subtitles <list>   Comma-separated list of subtitle streams to include (default: all)"
    echo "  -a, --audio <list>       Comma-separated list of audio streams to include (default: all)"
    echo "  -S, --single-audio       Interactive selection of a single audio track"
    echo "  -q, --quality <level>    Video quality: copy, h264, h265, h265fast, h265hw, repair (default: copy)"
    echo "  -m, --metadata <file>    JSON file with custom metadata"
    echo "  -l, --list-titles        List available titles and exit"
    echo "  -i, --info               Show detailed DVD information and exit"
    echo "  -h, --help              Show this help message"
    echo "  -p, --preserve-audio     Preserve original audio codec (don't convert to AAC)"
    echo "  --ffmpeg-concat          Use ffmpeg concat demuxer for VOB concatenation (fallback to cat if fails)"
    echo ""
    echo "Examples:"
    echo "  $0 /path/to/VIDEO_TS movie.mkv"
    echo "  $0 /path/to/VIDEO_TS movie.mkv -t 1 -s 0,1 -q h264"
    echo "  $0 /path/to/VIDEO_TS movie.mkv -q repair  # For corrupted DVDs"
    echo "  $0 /path/to/VIDEO_TS movie.mkv --metadata metadata.json"
    echo "  $0 /path/to/VIDEO_TS movie.mkv --list-titles"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    for dep in ffmpeg ffprobe jq; do
        if ! command -v "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        echo "Please install them:"
        echo "  macOS: brew install ffmpeg jq"
        echo "  Ubuntu/Debian: sudo apt install ffmpeg jq"
        echo "  CentOS/RHEL: sudo yum install ffmpeg jq"
        exit 1
    fi
}

# Function to validate DVD structure
validate_dvd_structure() {
    local dvd_path="$1"
    print_status "Validating DVD structure..." >&2
    if [ -d "$dvd_path/VIDEO_TS" ]; then
        print_status "Found VIDEO_TS directory" >&2
        local video_ts_path="$dvd_path/VIDEO_TS"
    elif [ -f "$dvd_path/VIDEO_TS.IFO" ] || [ -f "$dvd_path/VIDEO_TS.ifo" ]; then
        print_status "Found VIDEO_TS files in root directory" >&2
        local video_ts_path="$dvd_path"
    else
        local vts_count=$(find "$dvd_path" -iname "VTS_*_1.VOB" 2>/dev/null | wc -l)
        if [ "$vts_count" -gt 0 ]; then
            print_status "Found VTS files in root directory (ripped DVD structure)" >&2
            local video_ts_path="$dvd_path"
        else
            print_error "No valid DVD structure found. Expected VIDEO_TS directory, VIDEO_TS.IFO file, or VTS_*_1.VOB files." >&2
            exit 1
        fi
    fi
    local required_files=("VIDEO_TS.IFO" "VIDEO_TS.VOB")
    for file in "${required_files[@]}"; do
        local base_name="${file%.*}"
        local ext="${file##*.}"
        local lower_ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
        local upper_ext=$(echo "$ext" | tr '[:lower:]' '[:upper:]')
        
        if [ ! -f "$video_ts_path/$file" ] && [ ! -f "$video_ts_path/${base_name}.${lower_ext}" ]; then
            print_warning "Missing optional DVD file: $file" >&2
        fi
    done
    local vts_count=$(find "$video_ts_path" -iname "VTS_*_1.VOB" 2>/dev/null | wc -l)
    if [ "$vts_count" -eq 0 ]; then
        print_warning "No VTS_*_1.VOB files found. This might not be a movie DVD." >&2
    else
        print_success "Found $vts_count potential movie titles" >&2
    fi
    echo "$video_ts_path"
}

# Function to analyze DVD titles using VOB files
analyze_dvd_titles() {
    local dvd_path="$1"
    print_status "Analyzing DVD titles from VOB files..." >&2
    local titles=()
    local title_info=()
    while IFS= read -r -d '' vob_file; do
        local title_num=$(basename "$vob_file" | sed 's/VTS_\([0-9]*\)_1\.VOB/\1/i')
        local title_dir=$(dirname "$vob_file")
        local file_size=$(ls -lh "$vob_file" 2>/dev/null | awk '{print $5}' || echo "unknown")
        titles+=("$title_num")
        title_info+=("Title $title_num: Size=$file_size")
    done < <(find "$dvd_path" -iname "VTS_*_1.VOB" -print0 2>/dev/null)
    IFS=$'\n' titles=($(sort -n <<<"${titles[*]}"))
    unset IFS
    echo "${titles[@]}"
    printf '%s\n' "${title_info[@]}"
}

# Function to get detailed stream information
get_stream_info() {
    local dvd_path="$1"
    local title_num="$2"
    local title_num_padded=$(printf '%02d' "$title_num")
    echo "DEBUG: get_stream_info: dvd_path=[$dvd_path] title_num=[$title_num] (padded: $title_num_padded)"
    echo "DEBUG: Running: find \"$dvd_path\" -iname \"VTS_${title_num_padded}_1.VOB\""
    local vob_file=$(find "$dvd_path" -iname "VTS_${title_num_padded}_1.VOB" 2>/dev/null | head -1)
    echo "DEBUG: get_stream_info: vob_file=[$vob_file]"
    if [ -z "$vob_file" ]; then
        print_error "Title $title_num not found"
        return 1
    fi
    print_status "Analyzing streams for title $title_num..."
    print_status "Using VOB file: $vob_file"
    print_status "Available streams:"
    ffprobe -hide_banner -loglevel error -probesize 10000000 -analyzeduration 10000000 \
        -i "$vob_file" 2>&1 | grep "Stream #" || print_warning "Could not retrieve stream information"
}

# Function to extract metadata from DVD
extract_dvd_metadata() {
    local dvd_path="$1"
    local metadata_file="$2"
    local title_num="$3"
    local title_num_padded=$(printf '%02d' "$title_num")
    print_status "Extracting DVD metadata..."
    local dvd_structure=$(find "$dvd_path" -iname "*.VOB" -o -iname "*.IFO" -o -iname "*.BUP" 2>/dev/null | \
        sort | jq -R -s 'split("\n")[:-1]' 2>/dev/null || echo "[]")
    local title_info=$(analyze_dvd_titles "$dvd_path" 2>/dev/null | tail -n +2 | \
        jq -R -s 'split("\n")[:-1]' 2>/dev/null || echo "[]")
    local vob_file=$(find "$dvd_path" -iname "VTS_${title_num_padded}_1.VOB" 2>/dev/null | head -1)
    local stream_info="{}"
    if [ -n "$vob_file" ]; then
        stream_info=$(ffprobe -hide_banner -loglevel error -probesize 10000000 -analyzeduration 10000000 \
            -print_format json -show_streams -i "$vob_file" 2>/dev/null || echo "{}")
    else
        print_warning "Could not find VOB file for title $title_num"
    fi
    local metadata=$(cat <<EOF
{
  "dvd_path": "$dvd_path",
  "selected_title": $title_num,
  "dvd_structure": $dvd_structure,
  "available_titles": $title_info,
  "stream_info": $stream_info,
  "extraction_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "extraction_tool": "dvd-to-mkv.sh"
}
EOF
)
    echo "$metadata" > "$metadata_file"
    print_success "Metadata saved to $metadata_file"
}

# Function to list available titles
list_titles() {
    local dvd_path="$1"
    print_status "Available DVD titles:"
    analyze_dvd_titles "$dvd_path"
}

# Function to show detailed DVD information
show_dvd_info() {
    local dvd_path="$1"
    print_status "DVD Information:"
    get_stream_info "$dvd_path" 1
}

# Function to auto-select the best title (usually the longest one)
auto_select_title() {
    local dvd_path="$1"
    print_status "Auto-selecting best title..." >&2
    
    local titles=()
    local title_sizes=()
    
    # Find all VOB files and get their sizes
    while IFS= read -r -d '' vob_file; do
        local title_num=$(basename "$vob_file" | sed 's/VTS_\([0-9]*\)_1\.VOB/\1/i')
        local file_size=$(stat -f%z "$vob_file" 2>/dev/null || echo "0")
        
        # Only process if we got a valid title number
        if [[ "$title_num" =~ ^[0-9]+$ ]]; then
            # Check if we already have this title
            local found=false
            for i in "${!titles[@]}"; do
                if [ "${titles[$i]}" = "$title_num" ]; then
                    found=true
                    # Add to existing size
                    title_sizes[$i]=$((${title_sizes[$i]} + file_size))
                    break
                fi
            done
            
            if [ "$found" = false ]; then
                titles+=("$title_num")
                title_sizes+=("$file_size")
            fi
        fi
    done < <(find "$dvd_path" -iname "VTS_*_1.VOB" -print0 2>/dev/null)
    
    if [ ${#titles[@]} -eq 0 ]; then
        print_error "No titles found" >&2
        return 1
    fi
    
    # Find the title with the largest total size
    local max_size=0
    local selected_title=""
    
    for i in "${!titles[@]}"; do
        if [ "${title_sizes[$i]}" -gt "$max_size" ]; then
            max_size="${title_sizes[$i]}"
            selected_title="${titles[$i]}"
        fi
    done
    
    if [ -n "$selected_title" ]; then
        local size_mb=$((max_size / 1024 / 1024))
        print_success "Auto-selected title $selected_title (largest size: ${size_mb}MB)" >&2
        echo "$selected_title"
        return 0
    else
        print_error "Could not auto-select title" >&2
        return 1
    fi
} 