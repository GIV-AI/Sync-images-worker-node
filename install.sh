#!/bin/bash
# ============================================================================
# Image Sync - Installation Script
# ============================================================================
# Installs the image-sync tool to system directories.
#
# Installation paths:
#   /opt/image-sync/          - Application files (bin/, lib/)
#   /etc/image-sync/          - Configuration files
#   /var/log/giindia/image-sync/ - Log directory
#   /usr/local/bin/image-sync - Command symlink
#
# Usage: sudo ./install.sh
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

# Colors (for interactive output)
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
# SCRIPT DIRECTORY RESOLUTION
# ============================================================================
# ----------------------------------------------------------------------------
# There are two principal ways we can determine the directory of the script:
#
# 1. When the script is run via a symbolic link (symlink):
#    - "${BASH_SOURCE[0]}" gives the filename or symlink path used to invoke the script.
#    - We use readlink -f to resolve the real, absolute path ("REAL_PATH") to
#      the target file the symlink points to.
#    - dirname "$REAL_PATH" extracts the directory of the real file.
#    - cd into that directory and use pwd to get the canonical, absolute path.
#
# 2. When the script is not called through a symlink:
#    - We extract the directory name directly from "${BASH_SOURCE[0]}" (the script file itself),
#      without resolving any symlinks,
#      and use cd + pwd to get the absolute path.
#
# Both methods ensure that SCRIPT_DIR always points to the physical
# directory containing the actual script source, which is critical for locating
# companion files (bin/, lib/, conf/) reliably, no matter how the installer is invoked.
# ----------------------------------------------------------------------------
if [[ -L "${BASH_SOURCE[0]}" ]]; then
    REAL_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
    SCRIPT_DIR="$(cd "$(dirname "$REAL_PATH")" && pwd)"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

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

# ============================================================================
# PRE-FLIGHT CHECKS
# ============================================================================

# Root check
if [[ "$EUID" -ne 0 ]]; then
    log_error "This script must be run as root (use sudo)"
    exit 1
fi

# Check source files exist
if [[ ! -f "${SCRIPT_DIR}/bin/image-sync" ]]; then
    log_error "Source file not found: ${SCRIPT_DIR}/bin/image-sync"
    log_error "Please run this script from the project root directory"
    exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    log_error "Source file not found: ${SCRIPT_DIR}/lib/common.sh"
    exit 1
fi

if [[ ! -f "${SCRIPT_DIR}/conf/image-sync.conf" ]]; then
    log_error "Source file not found: ${SCRIPT_DIR}/conf/image-sync.conf"
    exit 1
fi

# ============================================================================
# INSTALLATION
# ============================================================================
echo ""
echo "${BOLD}Installing Image Sync Tool${NC}"
echo "========================================"
echo ""

# Create directories with secure permissions
log_info "Creating installation directories..."

OLD_UMASK=$(umask)
umask 027

mkdir -p "${INSTALL_DIR}/bin"
mkdir -p "${INSTALL_DIR}/lib"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

umask "$OLD_UMASK"

# Set directory permissions
chmod 755 "$INSTALL_DIR"
chmod 755 "${INSTALL_DIR}/bin"
chmod 755 "${INSTALL_DIR}/lib"
chmod 750 "$CONFIG_DIR"
chmod 750 "$LOG_DIR"

# Set ownership
chown -R root:root "$INSTALL_DIR"
chown root:root "$CONFIG_DIR"
chown root:root "$LOG_DIR"

# Copy application files (reject symlinks for security)
log_info "Installing application files..."

if [[ -f "${SCRIPT_DIR}/bin/image-sync" && ! -L "${SCRIPT_DIR}/bin/image-sync" ]]; then
    cp -f -- "${SCRIPT_DIR}/bin/image-sync" "${INSTALL_DIR}/bin/"
    chmod 755 "${INSTALL_DIR}/bin/image-sync"
else
    log_error "Invalid source: bin/image-sync"
    exit 1
fi

if [[ -f "${SCRIPT_DIR}/lib/common.sh" && ! -L "${SCRIPT_DIR}/lib/common.sh" ]]; then
    cp -f -- "${SCRIPT_DIR}/lib/common.sh" "${INSTALL_DIR}/lib/"
    chmod 644 "${INSTALL_DIR}/lib/common.sh"
else
    log_error "Invalid source: lib/common.sh"
    exit 1
fi

# Copy configuration (preserve existing)
log_info "Installing configuration..."

if [[ -f "${CONFIG_DIR}/image-sync.conf" ]]; then
    log_warning "Configuration file already exists: ${CONFIG_DIR}/image-sync.conf"
    log_warning "Preserving existing configuration (new template saved as image-sync.conf.new)"
    cp -f -- "${SCRIPT_DIR}/conf/image-sync.conf" "${CONFIG_DIR}/image-sync.conf.new"
    chmod 640 "${CONFIG_DIR}/image-sync.conf.new"
else
    cp -f -- "${SCRIPT_DIR}/conf/image-sync.conf" "${CONFIG_DIR}/"
    chmod 640 "${CONFIG_DIR}/image-sync.conf"
fi

# Create command symlink
log_info "Creating command symlink..."

if [[ -L "$SYMLINK_PATH" ]]; then
    rm -f -- "$SYMLINK_PATH"
fi

ln -sf -- "${INSTALL_DIR}/bin/image-sync" "$SYMLINK_PATH"

# ============================================================================
# POST-INSTALLATION
# ============================================================================
echo ""
echo "${GREEN}${BOLD}Installation Complete!${NC}"
echo ""
echo "Installed files:"
echo "  - Application:   ${INSTALL_DIR}/"
echo "  - Configuration: ${CONFIG_DIR}/image-sync.conf"
echo "  - Logs:          ${LOG_DIR}/"
echo "  - Command:       ${SYMLINK_PATH}"
echo ""
echo "${YELLOW}Next steps:${NC}"
echo "  1. Edit configuration: sudo nano ${CONFIG_DIR}/image-sync.conf"
echo "  2. Configure SSH keys for worker nodes"
echo "  3. Test manually: sudo image-sync"
echo "  4. Add to cron for automated sync"
echo ""
echo "Example cron entry (every 30 minutes):"
echo "  */30 * * * * /usr/local/bin/image-sync >> /var/log/giindia/image-sync/cron.log 2>&1"
echo ""

