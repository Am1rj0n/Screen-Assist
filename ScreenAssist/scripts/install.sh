#!/bin/bash

# ==============================================================================
# TA Tool Installer
# ==============================================================================
# 
# Engineering Best Practices:
# - Strict mode: exit on error, undefined variables, and pipe failures
# - Modular functions for logging and verification
# - Trap for cleanup on failure
# 
# Cybersecurity Best Practices:
# - Input validation for arguments
# - Secure temporary file handling
# - Verification of system dependencies
# - Least privilege: doesn't require sudo unless installing to /usr/local/bin
# ==============================================================================

set -euo pipefail

# --- Configuration ---
INSTALL_DIR="/usr/local/bin"
LOCAL_BIN_DIR="$(pwd)/.bin"
TOOL_NAME="TA"
SCRATCH_DIR=$(mktemp -d)

# --- Logging ---
log_info()  { echo -e "\033[0;32m[INFO]\033[0m $1"; }
log_warn()  { echo -e "\033[0;33m[WARN]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; exit 1; }

# --- Cleanup ---
cleanup() {
    rm -rf "$SCRATCH_DIR"
}
trap cleanup EXIT

# --- Verification ---
check_deps() {
    log_info "Verifying dependencies..."
    if ! command -v swiftc &> /dev/null; then
        log_error "Swift compiler (swiftc) not found. Please install Xcode Command Line Tools."
    fi
}

# --- Installation ---
install_tool() {
    local target_tool=$1
    log_info "Building tool: $target_tool..."

    # Compile the CLI tool
    # Note: In a real scenario, we'd include all necessary Core/Utils files
    swiftc CLI/main.swift -o "$SCRATCH_DIR/$target_tool"

    log_info "Installing to $INSTALL_DIR..."
    
    if [ ! -w "$INSTALL_DIR" ]; then
        log_warn "No write access to $INSTALL_DIR. Falling back to local bin: $LOCAL_BIN_DIR"
        mkdir -p "$LOCAL_BIN_DIR"
        mv "$SCRATCH_DIR/$target_tool" "$LOCAL_BIN_DIR/$target_tool"
        INSTALL_DIR="$LOCAL_BIN_DIR"
    else
        mv "$SCRATCH_DIR/$target_tool" "$INSTALL_DIR/$target_tool"
    fi

    chmod 755 "$INSTALL_DIR/$target_tool"
    log_info "Successfully installed $target_tool to $INSTALL_DIR"
}

# --- Main Logic ---
main() {
    local tool_to_install=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --tool)
                tool_to_install="$2"
                shift 2
                ;;
            *)
                log_error "Unknown argument: $1"
                ;;
        esac
    done

    if [[ -z "$tool_to_install" ]]; then
        log_error "Missing required argument: --tool <name>"
    fi

    if [[ "$tool_to_install" != "TA" ]]; then
        log_error "Only 'TA' tool is supported for this installer."
    fi

    check_deps
    install_tool "$tool_to_install"
}

main "$@"
