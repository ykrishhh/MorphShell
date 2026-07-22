#!/data/data/com.termux/files/usr/bin/bash
# tk-scanner — Network port scanner for Termux
# Wraps nmap with sane defaults for mobile use.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $(basename "$0") <target> [options]"
    echo ""
    echo "Targets:"
    echo "  <ip>              Single IP (e.g. 192.168.1.1)"
    echo "  <cidr>            IP range (e.g. 192.168.1.0/24)"
    echo "  <hostname>        Domain name (e.g. example.com)"
    echo ""
    echo "Options:"
    echo "  -p <ports>        Port range (default: 1-1024)"
    echo "  -s                Stealth scan (SYN scan, requires root)"
    echo "  -v                Verbose output"
    echo "  -o <file>         Save results to file"
    echo "  -T                Quick scan (top 100 common ports)"
    echo "  -A                Aggressive scan (OS detection, scripts)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") 192.168.1.1"
    echo "  $(basename "$0") 192.168.1.0/24 -T"
    echo "  $(basename "$0") example.com -p 80,443,8080"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET=""
PORTS="1-1024"
NMAP_ARGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        -p) [ -z "${2:-}" ] && { echo -e "${RED}[!] -p requires a port range${NC}"; exit 1; }
            PORTS="$2"; shift 2 ;;
        -s) NMAP_ARGS+=("-sS"); shift ;;
        -v) NMAP_ARGS+=("-v"); shift ;;
        -o) [ -z "${2:-}" ] && { echo -e "${RED}[!] -o requires a filename${NC}"; exit 1; }
            NMAP_ARGS+=("-oN" "$2"); shift 2 ;;
        -T) NMAP_ARGS+=("--top-ports" "100"); shift ;;
        -A) NMAP_ARGS+=("-A"); shift ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && { echo -e "${RED}[!] No target specified.${NC}"; usage; }

# Add port range unless using --top-ports
if ! printf '%s\n' "${NMAP_ARGS[@]}" 2>/dev/null | grep -q 'top-ports'; then
    NMAP_ARGS+=("-p" "$PORTS")
fi

echo -e "${CYAN}[*] Termux Scanner${NC}"
echo -e "${YELLOW}[*] Target: $TARGET${NC}"
echo -e "${YELLOW}[*] Ports: $PORTS${NC}"
echo -e "${YELLOW}[*] Args: ${NMAP_ARGS[*]}${NC}"
echo ""

# Run scan safely — no eval
nmap "${NMAP_ARGS[@]}" "$TARGET"

echo ""
echo -e "${GREEN}[+] Scan complete.${NC}"
