# DVD Smart Copy Script - Configurable Version

An improved, configurable version of the DVD copying script with enhanced features and flexibility.

## Features

- **Configuration File Support**: Use a config file to set default options
- **Command Line Arguments**: Override any setting via command line
- **Multiple Copy Methods**: Choose between rsync (fast) and ddrescue (robust)
- **Dry Run Mode**: See what would happen without actually doing it
- **Verbose Output**: Get detailed information about what's happening
- **Mount Only Mode**: Just mount the DVD without copying
- **Better Error Handling**: More informative error messages
- **Colored Output**: Easy-to-read colored status messages
- **Dependency Checking**: Ensures required tools are available

## Installation

1. Make the script executable:
   ```bash
   chmod +x copy-dvd-smart.sh
   ```

2. (Optional) Create a configuration file:
   ```bash
   cp dvd-copy.conf.example ~/.config/dvd-copy.conf
   ```

3. Edit the configuration file to match your setup:
   ```bash
   nano ~/.config/dvd-copy.conf
   ```

## Usage

### Basic Usage

```bash
# Copy DVD with default settings
./copy-dvd-smart.sh

# Copy to a specific subfolder
./copy-dvd-smart.sh "Movie Title"

# Use ddrescue for damaged discs
./copy-dvd-smart.sh -r

# Only mount the DVD (don't copy)
./copy-dvd-smart.sh -M

# Show what would be done without doing it
./copy-dvd-smart.sh -n
```

### Advanced Usage

```bash
# Use custom config file
./copy-dvd-smart.sh -c ~/my-config.conf

# Use different device and output directory
./copy-dvd-smart.sh -d /dev/sr1 -o ~/Movies

# Verbose output with ddrescue
./copy-dvd-smart.sh -r -v

# Dry run with custom mount point
./copy-dvd-smart.sh -n -m /mnt/dvd
```

### Command Line Options

| Option | Long Option | Description |
|--------|-------------|-------------|
| `-c` | `--config` | Configuration file path |
| `-d` | `--device` | DVD device path |
| `-o` | `--output` | Output directory |
| `-m` | `--mount` | Mount point |
| `-l` | `--log-dir` | Log directory |
| `-r` | `--ddrescue` | Use ddrescue for copying |
| `-M` | `--mount-only` | Only mount, don't copy |
| `-v` | `--verbose` | Enable verbose output |
| `-n` | `--dry-run` | Show what would be done |
| `-h` | `--help` | Show help message |

## Configuration File

The script looks for a configuration file at `~/.config/dvd-copy.conf`. You can create this file manually or let the script create it for you on first run.

### Configuration Options

| Option | Description | Default |
|--------|-------------|---------|
| `DEVICE` | DVD device path | `/dev/sr0` |
| `DEST_DIR` | Output directory | `$HOME/Videos/DVDs` |
| `DEFAULT_MOUNT` | Mount point | `/media/dvd` |
| `LOG_DIR` | Log directory | `$HOME/.dvd_copy_logs` |
| `USE_DDRESCUE` | Use ddrescue | `false` |
| `VERBOSE` | Verbose output | `false` |

### Example Configuration

```bash
# DVD device path
DEVICE="/dev/sr0"

# Output directory
DEST_DIR="$HOME/Videos/DVDs"

# Mount point
DEFAULT_MOUNT="/media/dvd"

# Log directory
LOG_DIR="$HOME/.dvd_copy_logs"

# Use ddrescue for damaged discs
USE_DDRESCUE=false

# Verbose output
VERBOSE=false
```

## Copy Methods

### rsync (Default)
- **Pros**: Fast, handles permissions, progress display
- **Cons**: May fail on damaged discs
- **Use when**: Discs are in good condition

### ddrescue
- **Pros**: Robust, can recover from damaged sectors
- **Cons**: Slower, requires more disk space for logs
- **Use when**: Discs are damaged or scratched

## Dependencies

The script requires these tools:
- `mount` / `umount` - For mounting DVDs
- `findmnt` - For checking mount status
- `rsync` - For copying (default method)
- `ddrescue` - For copying damaged discs (optional)

### Installing Dependencies

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install rsync gddrescue
```

**macOS:**
```bash
brew install rsync gddrescue
```

**Arch Linux:**
```bash
sudo pacman -S rsync ddrescue
```

## Troubleshooting

### Device Not Found
If you get "Device not found" errors:
1. Check if the DVD drive is connected
2. Verify the device path: `ls -la /dev/sr*`
3. Try a different device (e.g., `/dev/sr1`)

### Permission Denied
If you get permission errors:
1. Make sure you're in the `cdrom` group: `groups`
2. Add yourself to the group: `sudo usermod -a -G cdrom $USER`
3. Log out and back in

### Mount Failed
If mounting fails:
1. Check if a disc is inserted
2. Try different filesystem types (the script tries `iso9660` and `udf`)
3. Check if the mount point is available

### Copy Failed
If copying fails:
1. Try using ddrescue: `./copy-dvd-smart.sh -r`
2. Check available disk space
3. Verify write permissions to the destination directory

## Examples

### Quick DVD Copy
```bash
./copy-dvd-smart.sh "Pirates of the Caribbean"
```

### Copy Damaged Disc
```bash
./copy-dvd-smart.sh -r -v "Damaged Movie"
```

### Test Configuration
```bash
./copy-dvd-smart.sh -n -v
```

### Use Different Device
```bash
./copy-dvd-smart.sh -d /dev/sr1 -o ~/ExternalDrive/Movies
```

## Migration from Old Script

If you were using the old script:

1. **Backup your old script**: `cp copy-dvd-smart.sh copy-dvd-smart.sh.backup`
2. **Update your workflow**: The new script uses different default paths
3. **Create a config file**: Use the example provided
4. **Test with dry run**: `./copy-dvd-smart.sh -n`

## License

This script is provided as-is for educational and personal use. 