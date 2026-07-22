#!/data/data/com.termux/files/usr/bin/bash
# vuln-check — Quick web vulnerability scanner
# Checks for common misconfigs, headers, info leaks, and known paths.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") <target> [options]"
    echo ""
    echo "Target:"
    echo "  <url>             Full URL or domain"
    echo ""
    echo "Options:"
    echo "  -s                Stealth mode (slower, fewer requests)"
    echo "  -a                All checks (including destructive)"
    echo "  -o <file>         Save report"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") example.com"
    echo "  $(basename "$0") https://example.com -s"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET=""
STEALTH=""
ALL=""
OUTPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -s) STEALTH=1; shift ;;
        -a) ALL=1; shift ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

# Normalize URL
echo "$TARGET" | grep -q '^https\?://' || TARGET="https://$TARGET"

header "Vulnerability Check — $TARGET"

score=0
issues=0

check() {
    local result="$1"
    local severity="$2"
    local detail="$3"

    case "$severity" in
        critical) fail "CRITICAL: $result"; score=$((score + 10)); issues=$((issues + 1)) ;;
        high)     fail "HIGH: $result"; score=$((score + 7)); issues=$((issues + 1)) ;;
        medium)   warn "MEDIUM: $result"; score=$((score + 4)); issues=$((issues + 1)) ;;
        low)      info "LOW: $result"; score=$((score + 1)) ;;
        info)     info "INFO: $result" ;;
        ok)       ok "$result" ;;
    esac
    [ -n "$detail" ] && info "  └─ $detail"
}

# --- Headers ---
section "Security Headers"
headers=$(curl -sI -m 10 "$TARGET" 2>/dev/null)

# HSTS
echo "$headers" | grep -qi "strict-transport-security" && \
    check "HSTS enabled" "ok" || \
    check "No HSTS header" "medium" "Add Strict-Transport-Security"

# CSP
echo "$headers" | grep -qi "content-security-policy" && \
    check "CSP enabled" "ok" || \
    check "No Content-Security-Policy" "medium" "Add CSP header"

# X-Frame-Options
echo "$headers" | grep -qi "x-frame-options" && \
    check "X-Frame-Options set" "ok" || \
    check "No X-Frame-Options" "low" "Vulnerable to clickjacking"

# X-Content-Type-Options
echo "$headers" | grep -qi "x-content-type-options" && \
    check "X-Content-Type-Options set" "ok" || \
    check "No X-Content-Type-Options" "low" "MIME sniffing possible"

# Permissions-Policy
echo "$headers" | grep -qi "permissions-policy\|feature-policy" && \
    check "Permissions-Policy set" "ok" || \
    check "No Permissions-Policy" "info"

# Server header leak
server=$(echo "$headers" | grep -i "^server:" | head -1)
if [ -n "$server" ]; then
    check "Server header leaked" "low" "$server"
else
    check "Server header hidden" "ok"
fi

# X-Powered-By leak
powered=$(echo "$headers" | grep -i "^x-powered-by:" | head -1)
if [ -n "$powered" ]; then
    check "X-Powered-By leaked" "medium" "$powered"
else
    check "X-Powered-By hidden" "ok"
fi

# --- Information disclosure ---
section "Information Disclosure"

# Check common info-leak paths
for path in "/.env" "/.git/config" "/.htaccess" "/wp-config.php.bak" "/.DS_Store" "/server-status" "/server-info" "/.svn/entries" "/robots.txt" "/sitemap.xml" "/.well-known/security.txt"; do
    status=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$TARGET$path" 2>/dev/null)
    case "$status" in
        200)
            case "$path" in
                /.env|.git/config|.htaccess|wp-config.php.bak|.DS_Store|.svn/entries)
                    check "Exposed: $path" "high" "HTTP $status — sensitive file accessible"
                    ;;
                /server-status|/server-info)
                    check "Exposed: $path" "medium" "HTTP $status — server info leak"
                    ;;
                *)
                    check "Found: $path" "info" "HTTP $status"
                    ;;
            esac
            ;;
    esac
done

# --- Technology fingerprint ---
section "Technology Fingerprint"
tech_headers=$(echo "$headers" | grep -iE '(x-powered|x-generator|x-drupal|x-wordpress|x-shopify|cf-ray|server:|set-cookie)')
if [ -n "$tech_headers" ]; then
    echo "$tech_headers" | while IFS= read -r line; do
        info "$(echo "$line" | tr -d '\r')"
    done
else
    info "No technology headers detected"
fi

# --- SSL/TLS basics ---
section "SSL/TLS"
if echo "$TARGET" | grep -q "^https"; then
    cert_info=$(echo | openssl s_client -connect "$(echo "$TARGET" | sed 's|https://||;s|/.*||'):443" 2>/dev/null)
    
    # Expiry
    not_after=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
    if [ -n "$not_after" ]; then
        now_epoch=$(date +%s)
        exp_epoch=$(date -d "$not_after" +%s 2>/dev/null) || \
            exp_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null) || \
            exp_epoch=""
        if [ -n "$exp_epoch" ]; then
            days=$(( (exp_epoch - now_epoch) / 86400 ))
            [ $days -lt 7 ] && check "Certificate expires in $days days" "high" || \
            [ $days -lt 30 ] && check "Certificate expires in $days days" "medium" || \
            check "Certificate valid for $days days" "ok"
        fi
    fi

    # Protocol
    for ver in tls1 tls1_1; do
        result=$(echo | openssl s_client -connect "$(echo "$TARGET" | sed 's|https://||;s|/.*||'):443" -"$ver" 2>&1)
        if echo "$result" | grep -q "BEGIN CERTIFICATE\|Protocol.*TLSv1$"; then
            check "Outdated TLS: $ver supported" "medium" "Disable $ver"
        fi
    done
else
    info "Not HTTPS — skipping SSL checks"
fi

# --- Open redirect check ---
section "Open Redirect"
for param in "?url=https://evil.com" "?next=https://evil.com" "?redirect=https://evil.com" "?return=https://evil.com"; do
    resp=$(curl -sI -m 5 "$TARGET$param" 2>/dev/null)
    location=$(echo "$resp" | grep -i "^location:" | head -1)
    if echo "$location" | grep -qi "evil.com"; then
        check "Open redirect via $param" "high" "$location"
        break
    fi
done

# --- Summary ---
section "Summary"
echo ""
echo -e "  ${CYAN}Target:${NC}    $TARGET"
echo -e "  ${CYAN}Issues:${NC}    $issues"
echo -e "  ${CYAN}Risk Score:${NC} $score"

if [ $score -ge 20 ]; then
    echo -e "\n  ${RED}████████████████████ HIGH RISK ████████████████████${NC}"
elif [ $score -ge 10 ]; then
    echo -e "\n  ${YELLOW}████████████████ MEDIUM RISK ████████████████${NC}"
elif [ $score -ge 1 ]; then
    echo -e "\n  ${BLUE}████████ LOW RISK ████${NC}"
else
    echo -e "\n  ${GREEN}█████████ CLEAN █████████${NC}"
fi

echo ""
echo -e "${GREEN}[+] Vulnerability check complete.${NC}"
[ -n "$OUTPUT" ] && echo -e "Report saved to $OUTPUT"
