#!/bin/bash

set -e

# Colors for output / 输出颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color / 无颜色

# Messages / 消息
EN_MESSAGES=(
    "Starting installation..."
    "Detected OS:"
    "Downloading latest release..."
    "URL:"
    "Installing binary..."
    "Cleaning up..."
    "Installation completed successfully!"
    "You can now use 'sudo %s' from your terminal"
    "Failed to download binary from:"
    "Failed to download the binary"
    "curl is required but not installed. Please install curl first."
    "sudo is required but not installed. Please install sudo first."
    "Unsupported operating system"
    "Unsupported architecture:"
    "Checking for running Cursor instances..."
    "Found running Cursor processes. Attempting to close them..."
    "Successfully closed all Cursor instances"
    "Failed to close Cursor instances. Please close them manually"
    "Backing up storage.json..."
    "Backup created at:"
    "This script requires root privileges. Requesting sudo access..."
)

CN_MESSAGES=(
    "开始安装..."
    "检测到操作系统："
    "正在下载最新版本..."
    "下载地址："
    "正在安装程序..."
    "正在清理..."
    "安装成功完成！"
    "现在可以在终端中使用 'sudo %s' 了"
    "从以下地址下载二进制文件失败："
    "下载二进制文件失败"
    "需要 curl 但未安装。请先安装 curl。"
    "需要 sudo 但未安装。请先安装 sudo。"
    "不支持的操作系统"
    "不支持的架构："
    "正在检查运行中的Cursor进程..."
    "发现正在运行的Cursor进程，尝试关闭..."
    "成功关闭所有Cursor实例"
    "无法关闭Cursor实例，请手动关闭"
    "正在备份storage.json..."
    "备份已创建于："
    "此脚本需要root权限。正在请求sudo访问..."
)

# Detect system language / 检测系统语言
detect_language() {
    [[ $(locale | grep "LANG=zh_CN") ]] && echo "cn" || echo "en"
}

# Get message based on language / 根据语言获取消息
get_message() {
    local lang=$(detect_language)
    [[ "$lang" == "cn" ]] && echo "${CN_MESSAGES[$1]}" || echo "${EN_MESSAGES[$1]}"
}

# Print with color / 带颜色打印
print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; exit 1; }

# Check and request root privileges / 检查并请求root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_status "$(get_message 20)"
        if command -v sudo >/dev/null 2>&1; then
            exec sudo bash "$0" "$@"
        else
            print_error "$(get_message 11)"
        fi
    fi
}

# Close Cursor instances / 关闭Cursor实例
close_cursor_instances() {
    print_status "$(get_message 14)"
    if pgrep -x "Cursor" >/dev/null; then
        print_status "$(get_message 15)"
        if pkill -x "Cursor" 2>/dev/null; then
            sleep 2
            print_success "$(get_message 16)"
        else
            print_error "$(get_message 17)"
        fi
    fi
}

# Backup storage.json / 备份storage.json
backup_storage_json() {
    print_status "$(get_message 18)"
    local storage_path="$HOME/$([ "$(uname)" == "Darwin" ] && echo "Library/Application Support" || echo ".config")/Cursor/User/globalStorage/storage.json"
    if [ -f "$storage_path" ]; then
        cp "$storage_path" "${storage_path}.backup"
        print_success "$(get_message 19) ${storage_path}.backup"
    fi
}

# Detect OS / 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "darwin"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        print_error "$(get_message 12)"
    fi
}

# Get latest release version from GitHub / 从GitHub获取最新版本
get_latest_version() {
    curl -s "https://api.github.com/repos/yuaotian/go-cursor-help/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/'
}

# Get architecture / 获取架构
get_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        *) print_error "$(get_message 13) $(uname -m)" ;;
    esac
}

# Download with progress / 带进度下载
download_with_progress() {
    curl -L -f --progress-bar "$1" -o "$2"
}

# Install binary / 安装二进制文件
install_binary() {
    local OS=$(detect_os)
    local VERSION=$(get_latest_version)
    local VERSION_WITHOUT_V=${VERSION#v}
    local BINARY_NAME="cursor_id_modifier_${VERSION_WITHOUT_V}_${OS}_$(get_arch)"
    local DOWNLOAD_URL="https://github.com/yuaotian/go-cursor-help/releases/download/${VERSION}/${BINARY_NAME}"
    local TMP_DIR=$(mktemp -d)
    local FINAL_BINARY_NAME="cursor-id-modifier"
    local INSTALL_DIR="/usr/local/bin"

    print_status "$(get_message 2)"
    print_status "$(get_message 3) ${DOWNLOAD_URL}"

    if ! download_with_progress "$DOWNLOAD_URL" "$TMP_DIR/$BINARY_NAME"; then
        rm -rf "$TMP_DIR"
        print_error "$(get_message 8) $DOWNLOAD_URL"
    fi

    if [ ! -f "$TMP_DIR/$BINARY_NAME" ]; then
        rm -rf "$TMP_DIR"
        print_error "$(get_message 9)"
    fi

    print_status "$(get_message 4)"
    mkdir -p "$INSTALL_DIR"
    if ! mv "$TMP_DIR/$BINARY_NAME" "$INSTALL_DIR/$FINAL_BINARY_NAME" || ! chmod +x "$INSTALL_DIR/$FINAL_BINARY_NAME"; then
        rm -rf "$TMP_DIR"
        print_error "Failed to install binary"
    fi

    print_status "$(get_message 5)"
    rm -rf "$TMP_DIR"

    print_success "$(get_message 6)"
    printf "${GREEN}[✓]${NC} $(get_message 7)\n" "$FINAL_BINARY_NAME"

    if [ -x "$INSTALL_DIR/$FINAL_BINARY_NAME" ]; then
        "$INSTALL_DIR/$FINAL_BINARY_NAME" &
    else
        print_warning "Failed to start cursor-id-modifier"
    fi
}

# Check for required tools / 检查必需工具
check_requirements() {
    command -v curl >/dev/null 2>&1 || print_error "$(get_message 10)"
    command -v sudo >/dev/null 2>&1 || print_error "$(get_message 11)"
}

# Main installation process / 主安装过程
main() {
    print_status "$(get_message 0)"
    check_root "$@"
    check_requirements
    close_cursor_instances
    backup_storage_json
    print_status "$(get_message 1) $(detect_os)"
    install_binary
}

# Run main function / 运行主函数
main "$@"