#!/bin/bash

# DVD Smart Copy Script - Configurable Version
# This script intelligently copies DVD content with configurable options

set -euo pipefail

# Default configuration
DEFAULT_CONFIG_FILE="$HOME/.config/dvd-copy.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values (can be overridden by config file or command line)
DEVICE="/dev/sr0"
DEST_DIR="$HOME/Videos/DVDs"
DEFAULT_MOUNT="/media/dvd"
LOG_DIR="$HOME/.dvd_copy_logs"
USE_DDRESCUE=false
JUST_MOUNT=false
SKIP_MOUNT=false
VERBOSE=false
DRY_RUN=false
SUBFOLDER=""
CONFIG_FILE=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_debug() { 
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}🔍 DEBUG: $1${NC}"
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS] [SUBFOLDER]

Smart DVD copying script with configurable options.

OPTIONS:
    -c, --config FILE     Configuration file path (default: $DEFAULT_CONFIG_FILE)
    -d, --device DEVICE   DVD device path (default: $DEVICE)
    -o, --output DIR      Output directory (default: $DEST_DIR)
    -m, --mount POINT     Mount point (default: $DEFAULT_MOUNT)
    -l, --log-dir DIR     Log directory (default: $LOG_DIR)
    -r, --ddrescue        Use ddrescue for copying (more robust for damaged discs)
    -M, --mount-only      Only mount the DVD, don't copy
    -s, --skip-mount      Skip mounting, use existing mount point
    -v, --verbose         Enable verbose output
    -n, --dry-run         Show what would be done without actually doing it
    -h, --help            Show this help message

CONFIGURATION:
    The script can be configured via a config file. Create $DEFAULT_CONFIG_FILE
    with the following format:
    
    # DVD Copy Configuration
    DEVICE="/dev/sr0"
    DEST_DIR="/path/to/output"
    DEFAULT_MOUNT="/media/dvd"
    LOG_DIR="/path/to/logs"
    USE_DDRESCUE=false
    VERBOSE=false

EXAMPLES:
    $0                           # Copy DVD with default settings
    $0 "Movie Title"            # Copy to subfolder "Movie Title"
    $0 -c ~/my-config.conf      # Use custom config file
    $0 -d /dev/sr1 -o ~/Movies  # Use different device and output
    $0 -r -v                    # Use ddrescue with verbose output
    $0 -M                       # Only mount the DVD
    $0 -s -m /media/dvd         # Skip mounting, use existing mount at /media/dvd

EOF
}

# Function to load configuration from file
load_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        log_debug "Config file not found: $config_file"
        return 1
    fi
    
    log_debug "Loading configuration from: $config_file"
    
    # Source the config file, but only allow specific variables
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Remove quotes if present
        value=$(echo "$value" | sed 's/^["'\'']//;s/["'\'']$//')
        
        case "$key" in
            DEVICE) DEVICE="$value" ;;
            DEST_DIR) DEST_DIR="$value" ;;
            DEFAULT_MOUNT) DEFAULT_MOUNT="$value" ;;
            LOG_DIR) LOG_DIR="$value" ;;
            USE_DDRESCUE) USE_DDRESCUE="$value" ;;
            VERBOSE) VERBOSE="$value" ;;
            SKIP_MOUNT) SKIP_MOUNT="$value" ;;
            *) log_warning "Unknown config option: $key" ;;
        esac
    done < "$config_file"
}

# Function to create default config file
create_default_config() {
    local config_file="$1"
    local config_dir=$(dirname "$config_file")
    
    if [ ! -d "$config_dir" ]; then
        mkdir -p "$config_dir"
    fi
    
    cat > "$config_file" << EOF
# DVD Copy Configuration
# This file contains default settings for the DVD copy script

# DVD device path
DEVICE="/dev/sr0"

# Default output directory
DEST_DIR="$HOME/Videos/DVDs"

# Default mount point
DEFAULT_MOUNT="/media/dvd"

# Log directory
LOG_DIR="$HOME/.dvd_copy_logs"

# Use ddrescue for copying (more robust for damaged discs)
USE_DDRESCUE=false

# Enable verbose output
VERBOSE=false

# Skip mounting (use existing mount point)
SKIP_MOUNT=false
EOF
    
    log_success "Created default config file: $config_file"
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()
    
    for cmd in mount umount findmnt rsync; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ "$USE_DDRESCUE" = true ]; then
        if ! command -v ddrescue &> /dev/null; then
            missing_deps+=("ddrescue")
        fi
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Please install the missing packages and try again."
        exit 1
    fi
}

# Function to validate device
validate_device() {
    local device="$1"
    
    if [ "$SKIP_MOUNT" = true ]; then
        log_debug "Skipping device validation (skip-mount mode)"
        return 0
    fi
    
    if [ ! -b "$device" ]; then
        log_error "Device $device not found or not a block device."
        log_info "Available DVD devices:"
        ls -la /dev/sr* 2>/dev/null || log_warning "No DVD devices found in /dev/sr*"
        exit 1
    fi
    
    log_debug "Device $device is valid"
}

# Function to mount DVD
mount_dvd() {
    local device="$1"
    local mount_point="$2"
    
    if [ "$SKIP_MOUNT" = true ]; then
        log_info "Skip-mount mode: using existing mount point $mount_point"
        
        if [ ! -d "$mount_point" ]; then
            log_error "Mount point $mount_point does not exist"
            exit 1
        fi
        
        if [ "$DRY_RUN" = true ]; then
            log_debug "DRY RUN: Would use existing mount point $mount_point"
            echo "$mount_point"
            return 0
        fi
        
        # Check if the mount point actually contains DVD content
        if [ ! -f "$mount_point/VIDEO_TS/VIDEO_TS.IFO" ] && [ ! -f "$mount_point/VIDEO_TS/VIDEO_TS.BUP" ]; then
            log_warning "Mount point $mount_point doesn't appear to contain DVD content"
            log_info "Expected DVD structure not found. Continuing anyway..."
        fi
        
        echo "$mount_point"
        return 0
    fi
    
    # Check if already mounted
    local current_mount=$(findmnt -nr -S "$device" -o TARGET)
    
    if [ -n "$current_mount" ]; then
        log_success "$device is already mounted at $current_mount"
        echo "$current_mount"
        return 0
    fi
    
    log_info "Mounting $device to $mount_point..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "DRY RUN: Would mount $device to $mount_point"
        echo "$mount_point"
        return 0
    fi
    
    # Create mount point if it doesn't exist
    sudo mkdir -p "$mount_point"
    
    # Try different filesystem types
    local mount_success=false
    
    for fs_type in iso9660 udf; do
        if sudo mount -t "$fs_type" "$device" "$mount_point" 2>/dev/null; then
            log_success "Mounted $device to $mount_point (filesystem: $fs_type)"
            mount_success=true
            break
        fi
    done
    
    if [ "$mount_success" = false ]; then
        log_error "Failed to mount $device. Is a disc inserted?"
        exit 1
    fi
    
    echo "$mount_point"
}

# Function to copy with rsync
copy_with_rsync() {
    local source="$1"
    local dest="$2"
    local user="$3"
    
    log_info "Copying content from $source to $dest using rsync..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "DRY RUN: Would run: sudo -u $user rsync -a --info=progress2 $source/ $dest/"
        return 0
    fi
    
    sudo -u "$user" rsync -a --info=progress2 "$source"/ "$dest"/
}

# Function to copy with ddrescue
copy_with_ddrescue() {
    local source="$1"
    local dest="$2"
    local user="$3"
    local log_dir="$4"
    
    log_info "Copying content from $source to $dest using ddrescue..."
    
    if [ "$DRY_RUN" = true ]; then
        log_debug "DRY RUN: Would copy files with ddrescue"
        return 0
    fi
    
    # Create log directory
    mkdir -p "$log_dir"
    
    # Copy each file individually
    find "$source" -type f | while read -r src_file; do
        local rel_path="${src_file#$source/}"
        local dest_file="$dest/$rel_path"
        local log_file="$log_dir/$(basename "$rel_path").log"
        
        sudo -u "$user" mkdir -p "$(dirname "$dest_file")"
        log_info "Copying: $rel_path"
        
        sudo ddrescue -n "$src_file" "$dest_file" "$log_file"
        
        # Optional: retry pass for bad sectors (uncomment if needed)
        # sudo ddrescue -r3 "$src_file" "$dest_file" "$log_file"
    done
}

# Function to list DVD contents
list_dvd_contents() {
    local mount_point="$1"
    
    log_info "DVD contents:"
    if [ "$DRY_RUN" = true ]; then
        log_debug "DRY RUN: Would list contents of $mount_point"
        return 0
    fi
    
    ls -1 "$mount_point"/
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -d|--device)
                DEVICE="$2"
                shift 2
                ;;
            -o|--output)
                DEST_DIR="$2"
                shift 2
                ;;
            -m|--mount)
                DEFAULT_MOUNT="$2"
                shift 2
                ;;
            -l|--log-dir)
                LOG_DIR="$2"
                shift 2
                ;;
            -r|--ddrescue)
                USE_DDRESCUE=true
                shift
                ;;
            -M|--mount-only)
                JUST_MOUNT=true
                shift
                ;;
            -s|--skip-mount)
                SKIP_MOUNT=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$SUBFOLDER" ]; then
                    SUBFOLDER="$1"
                else
                    log_error "Too many arguments"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Load configuration
    if [ -n "$CONFIG_FILE" ]; then
        load_config "$CONFIG_FILE"
    elif [ -f "$DEFAULT_CONFIG_FILE" ]; then
        load_config "$DEFAULT_CONFIG_FILE"
    else
        log_info "No config file found. Creating default config at $DEFAULT_CONFIG_FILE"
        create_default_config "$DEFAULT_CONFIG_FILE"
        load_config "$DEFAULT_CONFIG_FILE"
    fi
    
    log_debug "Configuration loaded:"
    log_debug "  Device: $DEVICE"
    log_debug "  Destination: $DEST_DIR"
    log_debug "  Mount point: $DEFAULT_MOUNT"
    log_debug "  Log directory: $LOG_DIR"
    log_debug "  Use ddrescue: $USE_DDRESCUE"
    log_debug "  Skip mount: $SKIP_MOUNT"
    log_debug "  Verbose: $VERBOSE"
    log_debug "  Dry run: $DRY_RUN"
    
    # Check dependencies
    check_dependencies
    
    # Validate device (skip if using skip-mount mode)
    if [ "$SKIP_MOUNT" = false ]; then
        validate_device "$DEVICE"
    fi
    
    # Mount DVD (or use existing mount point)
    local mount_point
    mount_point=$(mount_dvd "$DEVICE" "$DEFAULT_MOUNT")
    
    # List contents
    list_dvd_contents "$mount_point"
    
    # Create log directory
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$LOG_DIR"
    fi
    
    # If just mounting, exit here
    if [ "$JUST_MOUNT" = true ]; then
        log_success "DVD mounted at $mount_point"
        log_info "Use --mount-only to only mount without copying"
        exit 0
    fi
    
    # Prepare destination directory
    if [ -n "$SUBFOLDER" ]; then
        DEST_DIR="$DEST_DIR/$SUBFOLDER"
        log_info "Using subfolder: $SUBFOLDER"
    fi
    
    if [ "$DRY_RUN" = false ]; then
        sudo mkdir -p "$DEST_DIR"
    fi
    
    # Determine target user
    local target_user="${SUDO_USER:-$(logname)}"
    log_info "Running copy as user: $target_user"
    
    # Copy content
    if [ "$USE_DDRESCUE" = true ]; then
        copy_with_ddrescue "$mount_point" "$DEST_DIR" "$target_user" "$LOG_DIR"
    else
        copy_with_rsync "$mount_point" "$DEST_DIR" "$target_user"
    fi
    
    log_success "DVD content copied to $DEST_DIR"
    
    if [ "$DRY_RUN" = false ]; then
        log_info "Log files saved to: $LOG_DIR"
    fi
}

# Run main function with all arguments
main "$@"

