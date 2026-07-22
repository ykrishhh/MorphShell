#!/data/data/com.termux/files/usr/bin/bash
# Shared color/output functions for Termux Security Toolkit

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

header() {
    echo -e "\n${CYAN}════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════${NC}"
}

section() {
    echo -e "\n${YELLOW}── $1 ──${NC}"
}

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
fail() { echo -e "  ${RED}✗${NC} $1"; }
info() { echo -e "  ${BLUE}ℹ${NC} $1"; }

# Check if a command exists
has_cmd() { command -v "$1" > /dev/null 2>&1; }

# Check root
need_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}[!] This tool requires root (run with tsu).${NC}"
        exit 1
    fi
}

# Confirm action
confirm() {
    read -rp "$(echo -e "${YELLOW}$1 [y/N]: ${NC}")" choice
    case "$choice" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Check Termux
is_termux() { [ -d "/data/data/com.termux" ]; }
