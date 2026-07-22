#!/data/data/com.termux/files/usr/bin/bash
# log-analyzer — Auth log brute force detector
# Parses auth logs for failed login attempts, brute force patterns, and suspicious IPs.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  -f <file>      Analyze a specific log file"
    echo "  -a             Analyze all available logs"
    echo "  -t <minutes>   Time window (default: 60)"
    echo "  -b <count>     Brute force threshold (default: 5)"
    echo "  -j             JSON output"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -f /var/log/auth.log"
    echo "  $(basename "$0") -f /var/log/secure"
    echo "  $(basename "$0") -a"
    echo ""
    echo "Log paths checked:"
    echo "  /var/log/auth.log"
    echo "  /var/log/secure"
    echo "  /var/log/auth.log.1"
    echo "  ~/.termux/auth.log"
    exit 1
}

LOG_FILE=""
TIME_WINDOW=60
THRESHOLD=5
JSON=""
ALL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f) LOG_FILE="$2"; shift 2 ;;
        -a) ALL=1; shift ;;
        -t) TIME_WINDOW="$2"; shift 2 ;;
        -b) THRESHOLD="$2"; shift 2 ;;
        -j) JSON=1; shift ;;
        -h|--help) usage ;;
        *) LOG_FILE="$1"; shift ;;
    esac
done

# Find log file
if [ -z "$LOG_FILE" ]; then
    for path in /var/log/auth.log /var/log/secure /var/log/auth.log.1 ~/.termux/auth.log; do
        if [ -f "$path" ]; then
            LOG_FILE="$path"
            break
        fi
    done
fi

[ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ] && {
    fail "No log file found."
    info "Provide one with: $(basename "$0") -f /path/to/log"
    info "On Termux, logs may be at: ~/.termux/auth.log"
    exit 1
}

header "Log Analyzer — $LOG_FILE"

# Count total lines
total_lines=$(wc -l < "$LOG_FILE")
info "Total lines: $total_lines"

# --- Failed logins ---
section "Failed Login Attempts"
failed=$(grep -ciE "failed|failure|invalid|refused" "$LOG_FILE" 2>/dev/null || echo "0")
if [ "$failed" -gt 0 ]; then
    warn "Failed attempts: $failed"

    # Top IPs
    section "Top Offending IPs"
    grep -iE "failed|failure|invalid|refused" "$LOG_FILE" 2>/dev/null | \
        grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
        sort | uniq -c | sort -rn | head -10 | \
        while read count ip; do
            if [ "$count" -ge "$THRESHOLD" ]; then
                fail "$ip — $count attempts (BRUTE FORCE)"
            else
                warn "$ip — $count attempts"
            fi
        done
else
    ok "No failed login attempts found"
fi

# --- Successful logins ---
section "Successful Logins"
success=$(grep -ciE "accepted|session opened|logged in" "$LOG_FILE" 2>/dev/null || echo "0")
info "Successful logins: $success"

if [ "$success" -gt 0 ]; then
    grep -iE "accepted|session opened|logged in" "$LOG_FILE" 2>/dev/null | tail -5 | \
        while IFS= read -r line; do
            info "$(echo "$line" | cut -c1-120)"
        done
fi

# --- Root access ---
section "Root/Sudo Access"
root_count=$(grep -ciE "root|sudo" "$LOG_FILE" 2>/dev/null || echo "0")
info "Root/sudo entries: $root_count"

# --- SSH activity ---
section "SSH Activity"
ssh_in=$(grep -ciE "sshd.*accepted\|sshd.*failed\|sshd.*invalid" "$LOG_FILE" 2>/dev/null || echo "0")
ssh_failed=$(grep -ciE "sshd.*failed\|sshd.*invalid" "$LOG_FILE" 2>/dev/null || echo "0")
info "SSH connections: $ssh_in"
[ "$ssh_failed" -gt 0 ] && warn "SSH failures: $ssh_failed"

# --- Time-based analysis ---
section "Activity by Hour (last $TIME_WINDOW minutes)"
recent_cutoff=$(date -d "-${TIME_WINDOW} minutes" "+%b %d %H" 2>/dev/null) || \
    recent_cutoff=$(date -v-"${TIME_WINDOW}"M "+%b %d %H" 2>/dev/null) || \
    recent_cutoff=""
if [ -n "$recent_cutoff" ]; then
    grep "^$recent_cutoff" "$LOG_FILE" 2>/dev/null | \
        awk '{print $3}' | sort | uniq -c | sort -rn | head -10 | \
        while read count hour; do
            info "$hour:00 — $count events"
        done
fi

# --- Unique users ---
section "Unique Users"
grep -oE "(for|user) [a-zA-Z0-9_-]+" "$LOG_FILE" 2>/dev/null | \
    awk '{print $NF}' | sort -u | head -20 | \
    while IFS= read -r user; do
        info "$user"
    done

# --- Brute force summary ---
section "Brute Force Summary"
bf_ips=$(grep -iE "failed|failure|invalid" "$LOG_FILE" 2>/dev/null | \
    grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | \
    sort | uniq -c | sort -rn | awk -v t="$THRESHOLD" '$1 >= t')

if [ -n "$bf_ips" ]; then
    bf_count=$(echo "$bf_ips" | wc -l)
    fail "Detected $bf_count brute force source(s):"
    echo "$bf_ips" | while read count ip; do
        fail "  $ip — $count attempts"
    done
else
    ok "No brute force patterns detected (threshold: $THRESHOLD)"
fi

echo ""
echo -e "${GREEN}[+] Analysis complete.${NC}"
