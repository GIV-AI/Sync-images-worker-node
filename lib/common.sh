#!/bin/bash
# ============================================================================
# Image Sync - Common Library Module
# ============================================================================
# Shared utilities for logging, configuration management, SSH helpers,
# and dependency validation.
#
# This module is sourced by the main executable and should not be run directly.
#
# Author: Global Infoventures - GRIL Team
# Date: 2025-12-04
# ============================================================================

# Prevent double-sourcing
[[ -n "$_COMMON_SH_LOADED" ]] && return 0
readonly _COMMON_SH_LOADED=1

# ============================================================================
# VERSION
# ============================================================================
readonly VERSION="2.0.0"

# ============================================================================
# LOG LEVEL FILTERING
# ============================================================================
# Associative array for log level priorities
declare -A LOG_LEVELS=([DEBUG]=0 [INFO]=1 [WARNING]=2 [ERROR]=3 [SUCCESS]=1)

# Default log level (set in validate_config, fallback for early logging)
# Only messages at or above this level will be logged
LOG_LEVEL="${LOG_LEVEL:-INFO}"

# ============================================================================
# LOGGING SYSTEM
# ============================================================================
# Log file path (set after config is loaded)
LOG_FILE=""
LOGFILE=""  # Alias for backwards compatibility

# Log management variables (defaults set in validate_config)
MAX_LOG_SIZE=""
LOG_RETENTION_DAYS=""

# ============================================================================
# LOG CLEANUP
# ============================================================================

# Safe append to a log file with size limit check
# Usage: safe_append_log "/path/to/file.log" "log entry"
# Returns 0 on success, 1 on error, 2 if size limit exceeded
safe_append_log() {
    local log_file="$1"
    local entry="$2"

    [[ -z "$log_file" || -z "$entry" ]] && return 1

    # Check if log file directory is writable
    local log_dir
    log_dir="$(dirname "$log_file")"
    [[ ! -w "$log_dir" ]] && return 1

    # Check if file exists and exceeds MAX_LOG_SIZE (skip write if exceeded)
    if [[ -f "$log_file" && -n "$MAX_LOG_SIZE" ]]; then
        local file_size
        file_size=$(stat -c %s "$log_file" 2>/dev/null || echo 0)
        if [[ $file_size -ge $MAX_LOG_SIZE ]]; then
            # Size limit reached for today, skip logging
            return 2
        fi
    fi

    # Append entry
    echo "$entry" >> "$log_file"
    return 0
}

# Clean up day-wise log files older than LOG_RETENTION_DAYS
# Usage: cleanup_old_logs "/path/to/log/directory"
cleanup_old_logs() {
    local log_dir="$1"
    local retention_days="$LOG_RETENTION_DAYS"

    # If log directory is not set or not a directory, return error
    [[ -z "$log_dir" || ! -d "$log_dir" ]] && return 1

    # Find and remove day-wise log files older than retention period
    # Matches patterns like: image-sync-2025-12-04.log, success_images-2025-12-04.log
    local deleted_count=0
    # Temporatily assign IFS to Empty string to prevent filename expansion
    while IFS= read -r -d '' old_file; do
        if [[ -f "$old_file" && ! -L "$old_file" ]]; then # -L is to prevent removal of symlinks
            rm -f -- "$old_file"
            ((deleted_count++))
        fi
    done < <(find "$log_dir" -maxdepth 1 -type f -regex '.*-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]\.log' -mtime +"$retention_days" -print0 2>/dev/null)

    # Log cleanup activity to log file if available (no console output for cron)
    if [[ $deleted_count -gt 0 && -n "$LOG_FILE" ]]; then
        safe_append_log "$LOG_FILE" "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] Cleaned up $deleted_count old log file(s)"
    fi
}

# ============================================================================
# LOG MESSAGE FUNCTIONS
# ============================================================================

log_message() {
    local level="${1:-INFO}"
    local message="$2"
    local configured_level="${LOG_LEVEL:-INFO}"

    # Get numeric priorities for comparison
    local level_priority="${LOG_LEVELS[$level]:-1}"
    local configured_priority="${LOG_LEVELS[$configured_level]:-1}"

    # Skip if message level is below configured threshold
    if [[ $level_priority -lt $configured_priority ]]; then
        return 0
    fi

    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local log_entry="[$timestamp] [$level] $message"

    # Write to log file if configured (with size limit check)
    if [[ -n "$LOG_FILE" ]]; then
        safe_append_log "$LOG_FILE" "$log_entry"
    else
        # Fallback to stderr when log file not configured
        echo "$log_entry" >&2
    fi
}

log_debug() {
    log_message "DEBUG" "$1"
}

log_info() {
    log_message "INFO" "$1"
}

log_error() {
    log_message "ERROR" "$1"
}

log_warning() {
    log_message "WARNING" "$1"
}

log_success() {
    log_message "SUCCESS" "$1"
}

# Legacy log function for compatibility
log() {
    log_info "$1"
}

# ============================================================================
# CONFIGURATION MANAGEMENT
# ============================================================================

# Get configuration file path
get_config_path() {
    echo "/etc/image-sync/image-sync.conf"
}

# Load configuration file
load_config() {
    local config_file
    config_file="$(get_config_path)"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    log_info "Loading configuration from: $config_file"
    # shellcheck source=/dev/null
    source "$config_file" || {
        log_error "Failed to load configuration file: $config_file"
        return 1
    }

    return 0
}

# Validate required configuration variables
validate_config() {
    local missing=()

    # Required variables
    [[ -z "$NODE1" ]] && missing+=("NODE1")
    [[ -z "$NODE2" ]] && missing+=("NODE2")
    [[ -z "$PREFIX1" ]] && missing+=("PREFIX1")
    [[ -z "$LOG_DIR" ]] && missing+=("LOG_DIR")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required configuration variables: ${missing[*]}"
        return 1
    fi

    # Set defaults for optional variables
    : "${MAX_PARALLEL:=4}" # : is do nothing command to not try to execute the command
    : "${TIME_OUT:=1800}"
    : "${PREFIX2:=}"
    : "${SSH_CONNECT_TIMEOUT:=10}"
    : "${LOG_LEVEL:=INFO}"
    : "${MAX_LOG_SIZE:=10485760}"
    : "${LOG_RETENTION_DAYS:=30}"

    # Validate numeric values
    # =~ is regex match operator
    if ! [[ "$MAX_PARALLEL" =~ ^[0-9]+$ ]] || [[ "$MAX_PARALLEL" -lt 1 ]]; then
        log_warning "Invalid MAX_PARALLEL value '$MAX_PARALLEL', using default: 4"
        MAX_PARALLEL=4
    fi

    if ! [[ "$TIME_OUT" =~ ^[0-9]+$ ]] || [[ "$TIME_OUT" -lt 60 ]]; then
        log_warning "Invalid TIME_OUT value '$TIME_OUT', using default: 1800"
        TIME_OUT=1800
    fi

    if ! [[ "$SSH_CONNECT_TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$SSH_CONNECT_TIMEOUT" -lt 1 ]]; then
        log_warning "Invalid SSH_CONNECT_TIMEOUT value '$SSH_CONNECT_TIMEOUT', using default: 10"
        SSH_CONNECT_TIMEOUT=10
    fi

    if ! [[ "$MAX_LOG_SIZE" =~ ^[0-9]+$ ]] || [[ "$MAX_LOG_SIZE" -lt 1024 ]]; then
        log_warning "Invalid MAX_LOG_SIZE value '$MAX_LOG_SIZE', using default: 10485760"
        MAX_LOG_SIZE=10485760
    fi

    if ! [[ "$LOG_RETENTION_DAYS" =~ ^[0-9]+$ ]] || [[ "$LOG_RETENTION_DAYS" -lt 1 ]]; then
        log_warning "Invalid LOG_RETENTION_DAYS value '$LOG_RETENTION_DAYS', using default: 30"
        LOG_RETENTION_DAYS=30
    fi

    # Validate LOG_LEVEL is a known level
    if [[ -z "${LOG_LEVELS[$LOG_LEVEL]+isset}" ]]; then
        log_warning "Invalid LOG_LEVEL value '$LOG_LEVEL', using default: INFO"
        LOG_LEVEL="INFO"
    fi

    return 0
}

# ============================================================================
# DEPENDENCY CHECKING
# ============================================================================

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

check_dependencies() {
    local missing=()

    for dep in ssh jq; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_error "Please install the missing tools and try again"
        return 1
    fi

    return 0
}

# ============================================================================
# SSH HELPERS
# ============================================================================

# Check SSH connectivity to a node
check_ssh() {
    local node="$1"
    local timeout="${SSH_CONNECT_TIMEOUT:-10}"

    log_info "Checking SSH connectivity to $node"

    if ssh -o BatchMode=yes -o ConnectTimeout="$timeout" "$node" "echo ok" >/dev/null 2>&1; then
        log_info "SSH OK: $node"
        return 0
    else
        log_error "Cannot connect to $node via SSH"
        log_error "Ensure SSH key-based authentication is configured"
        return 1
    fi
}

# Get images from a node via SSH
get_images() {
    local node="$1"
    local timeout="${SSH_CONNECT_TIMEOUT:-10}"
    local output
    local exit_code

    # Don't use 2>&1 - crictl warnings go to stderr and would corrupt JSON
    if ! output=$(ssh -o ConnectTimeout="$timeout" "$node" "crictl images -o json" 2>/dev/null); then
        exit_code=$?
        log_error "Failed to get images from $node (exit code: $exit_code)"
        return 1
    fi

    echo "$output"
}

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Initialize logging directory and files with day-wise naming
init_logging() {
    if [[ -z "$LOG_DIR" ]]; then
        log_error "LOG_DIR not configured"
        return 1
    fi

    # Create log directory if it doesn't exist
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || {
            log_error "Failed to create log directory: $LOG_DIR"
            return 1
        }
    fi

    # Get current date for day-wise log file naming
    local current_date
    current_date="$(date '+%Y-%m-%d')"

    # Set day-wise log file paths (format: name-YYYY-MM-DD.log)
    LOG_FILE="${LOG_DIR}/image-sync-${current_date}.log"
    LOGFILE="$LOG_FILE"  # Alias for backwards compatibility
    SUCCESS_LOG="${LOG_DIR}/success_images-${current_date}.log"
    FAILED_LOG="${LOG_DIR}/failed_images-${current_date}.log"

    # Export for use in subshells
    export LOG_FILE LOGFILE SUCCESS_LOG FAILED_LOG

    # Clean up old logs on startup
    cleanup_old_logs "$LOG_DIR"

    return 0
}

# Log a successful image pull
log_success_image() {
    local node="$1"
    local image="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local entry="[$timestamp] $node $image - SUCCESS"

    safe_append_log "$SUCCESS_LOG" "$entry"
}

# Log a failed image pull
log_failed_image() {
    local node="$1"
    local image="$2"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local entry="[$timestamp] $node $image - FAILED"

    safe_append_log "$FAILED_LOG" "$entry"
}

# Safe cleanup of temporary files
# Only removes files that:
#   1. Are regular files (not directories, devices, etc.)
#   2. Are not symbolic links (prevents symlink attacks)
#   3. Reside in the system temp directory
#   4. Match mktemp naming pattern (tmp.*)
cleanup_temp_files() {
    local files=("$@")
    local tmp_dir="${TMPDIR:-/tmp}"

    for file in "${files[@]}"; do
        # Skip empty arguments
        [[ -z "$file" ]] && continue

        # Validate: regular file, not symlink, in temp dir, matches pattern
        if [[ -f "$file" && ! -L "$file" && "$file" == "$tmp_dir"/tmp.* ]]; then
            rm -f -- "$file"
        fi
    done
}
