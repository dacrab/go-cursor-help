#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# Temporary directory for downloads
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

# Check for curl
if ! command -v curl >/dev/null 2>&1; then
    echo -e "${RED}Error: curl is required${NC}"
    exit 1
fi

# Detect system
case "$(uname -s)" in
    Linux*)  
        OS="linux"
        ARCH="x86_64"  # Linux only supports x64
        ;;
    Darwin*) 
        OS="darwin"
        case "$(uname -m)" in
            x86_64)         ARCH="x86_64";;  # Intel Mac
            aarch64|arm64)  ARCH="arm64";;   # Apple Silicon
            *)              echo -e "${RED}Unsupported macOS architecture${NC}"; exit 1;;
        esac
        ;;
    *)       
        echo -e "${RED}Unsupported OS${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}Starting installation...${NC}"
echo -e "${GREEN}Detected: $OS $ARCH${NC}"

# Set and create install directory
INSTALL_DIR="/usr/local/bin"
mkdir -p "$INSTALL_DIR" || {
    echo -e "${RED}Failed to create installation directory${NC}"
    exit 1
}

# Get latest release info
echo -e "${BLUE}Fetching latest release...${NC}"
LATEST_URL="https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest"
VERSION=$(curl -s "$LATEST_URL" | grep "tag_name" | cut -d'"' -f4 | sed 's/^v//')
BINARY_NAME="cursor-id-modifier_${VERSION}_${OS}_${ARCH}"
DOWNLOAD_URL=$(curl -s "$LATEST_URL" | grep -o "\"browser_download_url\": \"[^\"]*${BINARY_NAME}[^\"]*\"" | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo -e "${RED}Error: Binary not found for $OS $ARCH${NC}"
    exit 1
fi

echo -e "${GREEN}Found: $BINARY_NAME${NC}"
echo -e "${BLUE}Downloading...${NC}"

# Download and install
curl -#L "$DOWNLOAD_URL" -o "$TMP_DIR/cursor-id-modifier"
chmod +x "$TMP_DIR/cursor-id-modifier"
sudo mv "$TMP_DIR/cursor-id-modifier" "$INSTALL_DIR/"

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${BLUE}Running cursor-id-modifier...${NC}"

# Run with sudo
export AUTOMATED_MODE=1
if ! sudo -E cursor-id-modifier; then
    echo -e "${RED}Failed to run cursor-id-modifier${NC}"
    exit 1
fi
