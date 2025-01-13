#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Function to print colored messages
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to handle errors
handle_error() {
    print_msg "$RED" "Error: $1"
    exit 1
}

# Temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Check dependencies
command -v curl >/dev/null 2>&1 || handle_error "curl is required"

# Detect system
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
case "$OS" in
    linux)  
        ARCH="x86_64"
        BINARY_NAME="cursor-id-modifier_Linux_x86_64"
        ;;
    darwin) 
        case "$(uname -m)" in
            x86_64)         
                ARCH="x86_64"
                BINARY_NAME="cursor-id-modifier_macOS_x86_64"
                ;;
            aarch64|arm64)  
                ARCH="arm64"
                BINARY_NAME="cursor-id-modifier_macOS_arm64"
                ;;
            *)             handle_error "Unsupported macOS architecture";;
        esac
        ;;
    *)     handle_error "Unsupported OS";;
esac

print_msg "$BLUE" "Starting installation..."
print_msg "$GREEN" "Detected: $OS $ARCH"

# Set install directory
INSTALL_DIR="/usr/local/bin"
mkdir -p "$INSTALL_DIR" || handle_error "Failed to create installation directory"

# Get latest release
print_msg "$BLUE" "Fetching latest release..."
LATEST_URL="https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest"
VERSION=$(curl -s "$LATEST_URL" | grep "tag_name" | cut -d'"' -f4 | sed 's/^v//')

DOWNLOAD_URL=$(curl -s "$LATEST_URL" | grep -o "\"browser_download_url\": \"[^\"]*${BINARY_NAME}[^\"]*\"" | cut -d'"' -f4)

[ -z "$DOWNLOAD_URL" ] && handle_error "Binary not found for $OS $ARCH"

print_msg "$GREEN" "Found: $BINARY_NAME"
print_msg "$BLUE" "Downloading..."

# Install binary
curl -#L "$DOWNLOAD_URL" -o "$TMP_DIR/cursor-id-modifier"
chmod +x "$TMP_DIR/cursor-id-modifier"
sudo mv "$TMP_DIR/cursor-id-modifier" "$INSTALL_DIR/"

print_msg "$GREEN" "Installation complete!"
print_msg "$BLUE" "Running cursor-id-modifier..."

# Run the program
export AUTOMATED_MODE=1
if ! sudo -E cursor-id-modifier; then
    handle_error "Failed to run cursor-id-modifier"
fi
