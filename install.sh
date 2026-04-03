#!/usr/bin/env bash
set -e

# ── helpers ────────────────────────────────────────────────────────────────────
if [ -t 1 ]; then
    bold="\033[1m"; reset="\033[0m"
    green="\033[32m"; yellow="\033[33m"; red="\033[31m"
    blue="\033[34m"; gray="\033[90m"
else
    bold=""; reset=""; green=""; yellow=""; red=""; blue=""; gray=""
fi

ok()   { echo -e "${green}✓${reset} $*"; }
warn() { echo -e "${yellow}!${reset} $*"; }
fail() { echo -e "${red}✗${reset} $*" >&2; }
info() { echo -e "${blue}i${reset} $*"; }

# ── args ───────────────────────────────────────────────────────────────────────
GLOBAL=false
GLOBAL_BIN="/usr/local/bin"

for arg in "$@"; do
    case $arg in
        --global) GLOBAL=true ;;
        *) fail "Unknown option: $arg"; echo "Usage: $0 [--global]" >&2; exit 1 ;;
    esac
done

# ── locate repo root (directory containing this script) ───────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── check prerequisites ────────────────────────────────────────────────────────
if ! command -v swift &>/dev/null; then
    fail "swift not found in PATH."
    exit 1
fi

SWIFT_VERSION=$(swift --version 2>&1 | head -1)
echo ""
echo -e "${bold}Building agent-manager…${reset}  ${gray}${SWIFT_VERSION}${reset}"
echo ""

# ── build ──────────────────────────────────────────────────────────────────────
swift build -c release 2>&1 | sed "s/^/  /"

BINARY=".build/release/agent-manager"
if [ ! -f "$BINARY" ]; then
    fail "Build succeeded but binary not found at $BINARY"
    exit 1
fi

echo ""

# ── write repo config (lets the binary find skills/commands after install) ──────
write_repo_config() {
    local config_dir="$HOME/.config/agent-manager"
    mkdir -p "$config_dir"
    echo "$SCRIPT_DIR" > "$config_dir/repo"
    ok "Repo path saved to ${bold}~/.config/agent-manager/repo${reset}"
}

# ── install ────────────────────────────────────────────────────────────────────
if $GLOBAL; then
    DEST="$GLOBAL_BIN/agent-manager"
    info "Installing to ${bold}${DEST}${reset}"

    if [ -w "$GLOBAL_BIN" ]; then
        cp "$BINARY" "$DEST"
        chmod +x "$DEST"
    else
        warn "$(realpath "$GLOBAL_BIN") is not writable — using sudo"
        sudo cp "$BINARY" "$DEST"
        sudo chmod +x "$DEST"
    fi

    write_repo_config
    ok "Installed.  Run: ${bold}agent-manager${reset}"
else
    mkdir -p "$SCRIPT_DIR/bin"
    DEST="$SCRIPT_DIR/bin/agent-manager"
    cp "$BINARY" "$DEST"
    chmod +x "$DEST"
    write_repo_config
    ok "Installed.  Run: ${bold}./bin/agent-manager${reset}"
    info "Or add ${bold}$(realpath bin)${reset} to your PATH to run as ${bold}agent-manager${reset}"
fi

echo ""
