#!/data/data/com.termux/files/usr/bin/bash
# qtx-hunt — Run all QTX tools in parallel against a target
# ponytail: background jobs + wait, not a framework

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") <target> [options]"
    echo ""
    echo "Options:"
    echo "  -o <dir>       Output directory (default: ~/qtx-hunt/<target>)"
    echo "  -s             Skip scanner (nmap)"
    echo "  -r             Skip recon"
    echo "  -v             Skip vuln-check"
    echo "  -l             Skip ssl-check"
    echo "  -t             Skip nikto"
    echo "  -q             Quiet — only show final summary"
    echo ""
    echo "Runs scanner, recon, vuln-check, ssl-check, and nikto in parallel."
    echo "Results saved to ~/qtx-hunt/<target>/"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET=""
OUTDIR=""
SKIP_SCANNER=""
SKIP_RECON=""
SKIP_VULN=""
SKIP_SSL=""
SKIP_NIKTO=""
QUIET=""

while [ $# -gt 0 ]; do
    case "$1" in
        -o) OUTDIR="$2"; shift 2 ;;
        -s) SKIP_SCANNER=1; shift ;;
        -r) SKIP_RECON=1; shift ;;
        -v) SKIP_VULN=1; shift ;;
        -l) SKIP_SSL=1; shift ;;
        -t) SKIP_NIKTO=1; shift ;;
        -q) QUIET=1; shift ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && { fail "No target"; usage; }

# ponytail: output dir — one place for all results
OUTDIR="${OUTDIR:-$HOME/qtx-hunt/$TARGET}"
mkdir -p "$OUTDIR"

header "QTX Hunt — $TARGET"
info "Output: $OUTDIR"
echo ""

pids=()
names=()
started=0

run_tool() {
    local name="$1"
    shift
    local logfile="$OUTDIR/$name.log"

    [ -n "$QUIET" ] && exec > /dev/null 2>&1
    "$@" > "$logfile" 2>&1
    [ -z "$QUIET" ] && echo -e "  ${GREEN}✓${NC} $name done → $logfile"
}

# ponytail: fire-and-forget pattern — launch all, wait at the end
if [ -z "$SKIP_SCANNER" ] && has_cmd nmap; then
    bash -c "$(declare -f run_tool); run_tool 'scanner' '$SCRIPT_DIR/scanner.sh' '$TARGET' -T" &
    pids+=($!)
    names+=("scanner")
    started=$((started + 1))
fi

if [ -z "$SKIP_RECON" ]; then
    bash -c "$(declare -f run_tool); run_tool 'recon' '$SCRIPT_DIR/recon.sh' '$TARGET' -d" &
    pids+=($!)
    names+=("recon")
    started=$((started + 1))
fi

if [ -z "$SKIP_VULN" ]; then
    bash -c "$(declare -f run_tool); run_tool 'vuln-check' '$SCRIPT_DIR/vuln-check.sh' '$TARGET'" &
    pids+=($!)
    names+=("vuln-check")
    started=$((started + 1))
fi

if [ -z "$SKIP_SSL" ]; then
    bash -c "$(declare -f run_tool); run_tool 'ssl-check' '$SCRIPT_DIR/ssl-check.sh' '$TARGET' -c -t" &
    pids+=($!)
    names+=("ssl-check")
    started=$((started + 1))
fi

if [ -z "$SKIP_NIKTO" ] && has_cmd nikto; then
    bash -c "$(declare -f run_tool); run_tool 'nikto' '$SCRIPT_DIR/nikto-scan.sh' '$TARGET' -f" &
    pids+=($!)
    names+=("nikto")
    started=$((started + 1))
fi

if [ $started -eq 0 ]; then
    fail "No tools available to run"
    exit 1
fi

info "Launched $started scans in parallel"
echo ""

# ponytail: wait for all, collect exit codes
failures=0
for i in "${!pids[@]}"; do
    wait "${pids[$i]}" 2>/dev/null
    code=$?
    if [ $code -ne 0 ]; then
        warn "${names[$i]} exited with code $code"
        failures=$((failures + 1))
    fi
done

# Summary
echo ""
header "Results"

for f in "$OUTDIR"/*.log; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .log)
    lines=$(wc -l < "$f")
    size=$(du -h "$f" | cut -f1)
    info "$name — $lines lines, $size"
done

echo ""
ok "All scans complete. Results: $OUTDIR"
[ $failures -gt 0 ] && warn "$failures tool(s) had errors — check logs"
