#!/data/data/com.termux/files/usr/bin/bash
# tk-nikto-scan — Nikto wrapper with Termux fixes baked in

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") <target> [options]"
    echo ""
    echo "Options:"
    echo "  -p <port>      Port (default: 443)"
    echo "  -C <tuning>    Tuning (1-9,0 = specific checks)"
    echo "  -o <file>      Output file"
    echo "  -f             Full scan (-C all)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") example.com"
    echo "  $(basename "$0") example.com -f"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET=""
PORT="443"
TUNING=""
OUTPUT=""
FULL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -p) PORT="$2"; shift 2 ;;
        -C) TUNING="$2"; shift 2 ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -f) FULL=1; shift ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && { fail "No target"; usage; }

if ! has_cmd nikto; then
    fail "nikto not installed. Run: pkg install nikto"
    exit 1
fi

section "Checking nikto setup"

if ! perl -e "use IO::Socket::SSL" 2>/dev/null; then
    warn "IO::Socket::SSL missing — installing..."
    cpan -T IO::Socket::SSL > /dev/null 2>&1
    ok "IO::Socket::SSL installed"
else
    ok "IO::Socket::SSL OK"
fi

NIKTO_CONF="/data/data/com.termux/files/usr/share/nikto/program/nikto.conf"
NIKTO_DEFAULT="/data/data/com.termux/files/usr/share/nikto/program/nikto.conf.default"
if [ ! -f "$NIKTO_CONF" ] && [ -f "$NIKTO_DEFAULT" ]; then
    warn "nikto.conf missing — creating from default..."
    cp "$NIKTO_DEFAULT" "$NIKTO_CONF"
    sed -i 's|TEMPLATES=/usr/share/nikto/program/templates|TEMPLATES=/data/data/com.termux/files/usr/share/nikto/program/templates|' "$NIKTO_CONF"
    ok "nikto.conf created"
else
    ok "nikto.conf OK"
fi

mkdir -p ~/nikto-output

NIKTO_CMD="nikto -h $TARGET -p $PORT"
[ -n "$TUNING" ] && NIKTO_CMD="$NIKTO_CMD -Tuning $TUNING"
[ -n "$FULL" ] && NIKTO_CMD="$NIKTO_CMD -C all"

OUT_FILE="${OUTPUT:-~/nikto-output/nikto-$(date +%Y%m%d-%H%M%S).txt}"
NIKTO_CMD="$NIKTO_CMD -output $OUT_FILE"

header "Nikto Scan — $TARGET:$PORT"
info "Command: $NIKTO_CMD"
echo ""

eval $NIKTO_CMD

echo ""
ok "Scan complete. Results: $OUT_FILE"
