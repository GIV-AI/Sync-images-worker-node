#!/bin/bash
# ============================================================================
# Image Sync - Uninstallation Script
# ============================================================================
# Removes the image-sync tool from system directories.
#
# Removal paths:
#   /opt/image-sync/          - Application files
#   /usr/local/bin/image-sync - Command symlink
#   /etc/image-sync/          - Configuration (optional, prompts)
#   /var/log/giindia/image-sync/ - Logs (optional, prompts)
#
# Usage: sudo ./uninstall.sh [--purge]
#
# Options:
#   --purge    Remove configuration and logs without prompting
#
# Author: Global Infoventures - GRIL Team
# Date: 2025-12-04
# ============================================================================

set -e
set -o pipefail

# ============================================================================
# CONSTANTS
# ============================================================================
readonly INSTALL_DIR="/opt/image-sync"
readonly CONFIG_DIR="/etc/image-sync"
readonly LOG_DIR="/var/log/giindia/image-sync"
readonly SYMLINK_PATH="/usr/local/bin/image-sync"
readonly LOCK_FILE="/var/run/image-sync.lock"

# Colors
if [[ -t 1 ]]; then
    readonly RED=$'\033[0;31m'
    readonly GREEN=$'\033[0;32m'
    readonly YELLOW=$'\033[1;33m'
    readonly NC=$'\033[0m'
    readonly BOLD=$'\033[1m'
else
    readonly RED=""
    readonly GREEN=""
    readonly YELLOW=""
    readonly NC=""
    readonly BOLD=""
fi

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================
PURGE_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge)
            PURGE_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--purge]"
            echo ""
            echo "Options:"
            echo "  --purge    Remove configuration and logs without prompting"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Safe directory removal (rejects symlinks)
safe_remove_dir() {
    local target="$1"

    if [[ ! -e "$target" ]]; then
        log_warning "Directory does not exist: $target"
        return 0
    fi

    if [[ -L "$target" ]]; then
        log_error "Refusing to remove symlink: $target"
        return 1
    fi

    if [[ ! -d "$target" ]]; then
        log_error "Not a directory: $target"
        return 1
    fi

    rm -rf -- "$target"
    log_info "Removed: $target"
}

# Prompt user for confirmation
prompt_yes_no() {
    local prompt="$1"
    local response

    # In purge mode, always return yes
    if [[ "$PURGE_MODE" == "true" ]]; then
        return 0
    fi

    # Non-interactive mode: default to no
    if [[ ! -t 0 ]]; then
        return 1
    fi

    while true; do
        read -r -p "$prompt [y/N]: " response
        case "${response,,}" in
            y|yes)
                return 0
                ;;
            n|no|"")
                return 1
                ;;
            *)
                echo "Please answer yes or no."
                ;;
        esac
    done
}

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

# Root check
if [[ "$EUID" -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check if anything is installed
if [[ ! -d "$INSTALL_DIR" && ! -L "$SYMLINK_PATH" && ! -d "$CONFIG_DIR" ]]; then
    log_warning "Image Sync does not appear to be installed"
    exit 0
fi

# ============================================================================
# UNINSTALLATION
# ============================================================================
echo ""
echo "${BOLD}Uninstalling Image Sync Tool${NC}"
echo "========================================"
echo ""

# Remove application files
if [[ -d "$INSTALL_DIR" ]]; then
    log_info "Removing application files..."
    safe_remove_dir "$INSTALL_DIR"
else
    log_warning "Application directory not found: $INSTALL_DIR"
fi

# Remove command symlink
if [[ -L "$SYMLINK_PATH" ]]; then
    log_info "Removing command symlink..."
    rm -f -- "$SYMLINK_PATH"
    log_info "Removed: $SYMLINK_PATH"
elif [[ -e "$SYMLINK_PATH" ]]; then
    log_warning "Symlink path exists but is not a symlink: $SYMLINK_PATH"
    log_warning "Skipping removal (manual intervention required)"
fi

# Remove lock file
if [[ -f "$LOCK_FILE" ]]; then
    log_info "Removing lock file..."
    rm -f -- "$LOCK_FILE"
fi

# ============================================================================
# OPTIONAL: REMOVE CONFIGURATION
# ============================================================================
if [[ -d "$CONFIG_DIR" ]]; then
    echo ""
    if prompt_yes_no "Remove configuration directory ($CONFIG_DIR)?"; then
        safe_remove_dir "$CONFIG_DIR"
    else
        log_info "Configuration preserved: $CONFIG_DIR"
    fi
fi

# ============================================================================
# OPTIONAL: REMOVE LOGS
# ============================================================================
if [[ -d "$LOG_DIR" ]]; then
    echo ""
    if prompt_yes_no "Remove log directory ($LOG_DIR)?"; then
        safe_remove_dir "$LOG_DIR"

        # Clean up parent directory if empty
        parent_dir="$(dirname "$LOG_DIR")"
        if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir")" ]]; then
            rmdir -- "$parent_dir" 2>/dev/null || true
        fi
    else
        log_info "Logs preserved: $LOG_DIR"
    fi
fi

# ============================================================================
# COMPLETION
# ============================================================================
echo ""
echo "${GREEN}${BOLD}Uninstallation Complete!${NC}"
echo ""

if [[ -d "$CONFIG_DIR" || -d "$LOG_DIR" ]]; then
    echo "${YELLOW}Note:${NC} Some files were preserved:"
    [[ -d "$CONFIG_DIR" ]] && echo "  - Configuration: $CONFIG_DIR"
    [[ -d "$LOG_DIR" ]] && echo "  - Logs: $LOG_DIR"
    echo ""
    echo "To remove everything, run: sudo $0 --purge"
    echo ""
fi

