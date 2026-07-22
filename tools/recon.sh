#!/data/data/com.termux/files/usr/bin/bash
# tk-recon — OSINT reconnaissance for Termux
# Gathers public info about a target without touching it.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") <target> [options]"
    echo ""
    echo "Targets:"
    echo "  <domain>          Domain name (e.g. example.com)"
    echo "  <ip>              IP address"
    echo ""
    echo "Options:"
    echo "  -o <file>         Save output to file"
    echo "  -q                Quiet mode (results only)"
    echo "  -d                Deep recon (slower, more thorough)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") example.com"
    echo "  $(basename "$0") 8.8.8.8 -d"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET=""
OUTPUT=""
QUIET=""
DEEP=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o) [ -z "${2:-}" ] && { echo -e "${RED}[!] -o requires a filename${NC}"; exit 1; }
            OUTPUT="$2"; shift 2 ;;
        -q) QUIET=1; shift ;;
        -d) DEEP=1; shift ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && { echo -e "${RED}[!] No target specified.${NC}"; usage; }

log() {
    [ -z "$QUIET" ] && echo -e "$1"
    [ -n "$OUTPUT" ] && echo -e "$1" >> "$OUTPUT"
}

result() {
    echo -e "$1"
    [ -n "$OUTPUT" ] && echo -e "$1" >> "$OUTPUT"
}

echo -e "${CYAN}[*] Termux Recon — $TARGET${NC}"
echo ""

# --- DNS ---
section "DNS Records"
if command -v dig > /dev/null 2>&1; then
    for type in A AAAA MX NS TXT CNAME; do
        records=$(dig +short "$TARGET" "$type" 2>/dev/null)
        [ -n "$records" ] && result "  $type: $records"
    done
elif command -v host > /dev/null 2>&1; then
    host "$TARGET" 2>/dev/null | sed 's/^/  /'
else
    ip=$(curl -s "https://dns.google/resolve?name=${TARGET}&type=A" 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('\n'.join(a['data'] for a in d.get('Answer',[])))" 2>/dev/null)
    [ -n "$ip" ] && result "  A: $ip"
fi
echo ""

# --- HTTP headers ---
section "HTTP Headers"
for proto in https http; do
    headers=$(curl -sI -m 5 "$proto://$TARGET" 2>/dev/null)
    if [ -n "$headers" ]; then
        result "  [$proto]"
        echo "$headers" | grep -iE '^(server|x-|content-type|location|set-cookie|strict-transport)' | sed 's/^/    /'
        break
    fi
done
echo ""

# --- WHOIS (if available) ---
if command -v whois > /dev/null 2>&1; then
    section "WHOIS"
    whois "$TARGET" 2>/dev/null | grep -iE '(registrar|creation|expir|name server|org|country)' | head -10 | sed 's/^/  /'
    echo ""
fi

# --- Reverse DNS ---
section "Reverse DNS"
if echo "$TARGET" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    rev=$(dig +short -x "$TARGET" 2>/dev/null)
    [ -n "$rev" ] && result "  $TARGET → $rev" || result "  No PTR record"
else
    ips=$(dig +short "$TARGET" A 2>/dev/null)
    for ip in $ips; do
        rev=$(dig +short -x "$ip" 2>/dev/null)
        [ -n "$rev" ] && result "  $ip → $rev"
    done
fi
echo ""

# --- Deep recon ---
if [ -n "$DEEP" ]; then
    section "Deep Recon"

    # Subdomains (common ones)
    log "  Checking common subdomains..."
    for sub in www mail ftp vpn api cdn blog dev staging admin panel db git; do
        ip=$(dig +short "$sub.$TARGET" A 2>/dev/null)
        [ -n "$ip" ] && result "  $sub.$TARGET → $ip"
    done
    echo ""

    # Technology detection via headers
    log "  Technology fingerprint..."
    tech=$(curl -sI -m 5 "https://$TARGET" 2>/dev/null)
    echo "$tech" | grep -iE '(x-powered-by|x-aspnet|x-generator|x-drupal|x-wordpress|x-shopify|cf-ray|server:)' | sed 's/^/  /'
    echo ""
fi

# --- Port check (common) ---
section "Common Ports"
for port in 22 80 443 8080 8443 3000 5000 21 25 53 110 143 993 995 3306 5432 6379 27017; do
    (echo > /dev/tcp/"$TARGET"/"$port") 2>/dev/null && result "  $port open" &
done
wait
echo ""

echo -e "${GREEN}[+] Recon complete.${NC}"
[ -n "$OUTPUT" ] && echo -e "${GREEN}[+] Results saved to $OUTPUT${NC}"
