#!/usr/bin/env bash

# sym - Installation Script
# Installs sym to ~/.local/bin and optionally builds the man page
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/11ways/sym/main/install.sh | bash
#
# Or safer (inspect first):
#   curl -fsSL https://raw.githubusercontent.com/11ways/sym/main/install.sh -o install.sh
#   less install.sh
#   bash install.sh

set -euo pipefail

# === CONFIGURATION ===
readonly REPO="11ways/sym"
readonly BRANCH="${SYM_INSTALL_BRANCH:-main}"
readonly INSTALL_DIR="${SYM_DIR:-$HOME/.local/bin}"
readonly MAN_DIR="$HOME/.local/share/man/man1"
readonly TEMP_DIR=$(mktemp -d)

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BLUE='' BOLD='' RESET=''
fi

# === HELPER FUNCTIONS ===

info() {
    echo -e "${BLUE}ℹ${RESET} $*"
}

success() {
    echo -e "${GREEN}✓${RESET} $*"
}

warn() {
    echo -e "${YELLOW}⚠${RESET} $*" >&2
}

error() {
    echo -e "${RED}✗${RESET} $*" >&2
    exit 1
}

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

check_command() {
    command -v "$1" >/dev/null 2>&1
}

download_file() {
    local url="$1"
    local output="$2"

    if check_command curl; then
        curl -fsSL "$url" -o "$output" || error "Failed to download $url"
    elif check_command wget; then
        wget -q -O "$output" "$url" || error "Failed to download $url"
    else
        error "Neither curl nor wget found. Please install one of them."
    fi
}

# === MAIN INSTALLATION ===

main() {
    echo ""
    echo -e "${BOLD}sym - Symbolic Link Manager${RESET}"
    echo -e "${BLUE}Installing to: $INSTALL_DIR${RESET}"
    echo ""

    # Check prerequisites
    if ! check_command bash; then
        error "bash is required but not found"
    fi

    # Create directories
    info "Creating directories..."
    mkdir -p "$INSTALL_DIR" || error "Failed to create $INSTALL_DIR"
    mkdir -p "$MAN_DIR" || error "Failed to create $MAN_DIR"

    # Download main script
    info "Downloading sym..."
    local script_url="https://raw.githubusercontent.com/$REPO/$BRANCH/sym.sh"
    download_file "$script_url" "$TEMP_DIR/sym.sh"

    # Make executable
    chmod +x "$TEMP_DIR/sym.sh"

    # Verify it works
    if ! bash "$TEMP_DIR/sym.sh" --version >/dev/null 2>&1; then
        error "Downloaded script failed verification"
    fi

    # Install script
    info "Installing sym to $INSTALL_DIR..."
    cp "$TEMP_DIR/sym.sh" "$INSTALL_DIR/sym" || error "Failed to copy sym"
    success "Installed sym"

    # Download and build man page
    if check_command pandoc; then
        info "pandoc found, building man page..."

        local manpage_url="https://raw.githubusercontent.com/$REPO/$BRANCH/sym.1.md"
        download_file "$manpage_url" "$TEMP_DIR/sym.1.md"

        # Build man page
        if pandoc --standalone --from markdown --to man "$TEMP_DIR/sym.1.md" -o "$TEMP_DIR/sym.1" 2>/dev/null; then
            # Compress and install
            gzip -9 "$TEMP_DIR/sym.1"
            cp "$TEMP_DIR/sym.1.gz" "$MAN_DIR/sym.1.gz" || warn "Failed to install man page"
            success "Installed man page"
        else
            warn "Failed to build man page"
        fi
    else
        warn "pandoc not found, skipping man page installation"
        info "To install man page, install pandoc and run: make install-local"
    fi

    # Check if directory is in PATH
    echo ""
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        warn "$INSTALL_DIR is not in your PATH"
        echo ""
        echo -e "${BOLD}Add to your shell configuration:${RESET}"
        echo ""
        echo -e "  ${GREEN}# Add to ~/.bashrc or ~/.zshrc${RESET}"
        echo -e "  ${BLUE}export PATH=\"\$PATH:$INSTALL_DIR\"${RESET}"
        echo ""
        echo "Then reload your shell:"
        echo -e "  ${BLUE}source ~/.bashrc${RESET}  # or source ~/.zshrc"
        echo ""
    fi

    # Check if MANPATH needs updating
    if [[ ":$MANPATH:" != *":$HOME/.local/share/man:"* ]] && [[ -f "$MAN_DIR/sym.1.gz" ]]; then
        warn "Man page installed but may not be in MANPATH"
        echo ""
        echo -e "${BOLD}To enable 'man sym', add to your shell configuration:${RESET}"
        echo ""
        echo -e "  ${GREEN}# Add to ~/.bashrc or ~/.zshrc${RESET}"
        echo -e "  ${BLUE}export MANPATH=\"\$MANPATH:$HOME/.local/share/man\"${RESET}"
        echo ""
    fi

    # Success message
    echo ""
    echo -e "${GREEN}${BOLD}✓ Installation complete!${RESET}"
    echo ""
    echo "Try it out:"
    echo -e "  ${BLUE}$INSTALL_DIR/sym --version${RESET}"
    echo -e "  ${BLUE}$INSTALL_DIR/sym --help${RESET}"

    if [[ -f "$MAN_DIR/sym.1.gz" ]]; then
        echo -e "  ${BLUE}man sym${RESET}"
    fi

    echo ""
    echo "Get started:"
    echo -e "  ${BLUE}sym ls${RESET}                    # List all symlinks"
    echo -e "  ${BLUE}sym mylink /path/to/file${RESET}  # Create a symlink"
    echo ""
    echo "For more information:"
    echo -e "  ${BLUE}https://github.com/$REPO${RESET}"
    echo ""
}

# Run installation
main "$@"
