#!/data/data/com.termux/files/usr/bin/bash
# ssl-check — SSL/TLS certificate inspector
# Checks certificates, chain validity, protocols, and ciphers.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") <domain> [options]"
    echo ""
    echo "Options:"
    echo "  -p <port>      Port to check (default: 443)"
    echo "  -c             Check certificate chain"
    echo "  -t             Test supported TLS versions"
    echo "  -j             JSON output"
    echo "  -o <file>      Save report to file"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") example.com"
    echo "  $(basename "$0") example.com -c -t"
    echo "  $(basename "$0") google.com -j"
    exit 1
}

[ $# -lt 1 ] && usage

DOMAIN=""
PORT=443
CHAIN=""
TLS_TEST=""
JSON=""
OUTPUT=""

while [ $# -gt 0 ]; do
    case "$1" in
        -p) PORT="$2"; shift 2 ;;
        -c) CHAIN=1; shift ;;
        -t) TLS_TEST=1; shift ;;
        -j) JSON=1; shift ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) DOMAIN="$1"; shift ;;
    esac
done

[ -z "$DOMAIN" ] && { echo -e "${RED}[!] No domain specified.${NC}"; usage; }

header "SSL/TLS Check — $DOMAIN:$PORT"

# --- Certificate info ---
section "Certificate"
cert_info=$(echo | openssl s_client -connect "$DOMAIN:$PORT" -servername "$DOMAIN" 2>/dev/null)

if [ -z "$cert_info" ] || echo "$cert_info" | grep -q "connect:errno"; then
    fail "Could not connect to $DOMAIN:$PORT"
    exit 1
fi

# Subject & Issuer
subject=$(echo "$cert_info" | openssl x509 -noout -subject 2>/dev/null | sed 's/^subject=//')
issuer=$(echo "$cert_info" | openssl x509 -noout -issuer 2>/dev/null | sed 's/^issuer=//')
ok "Subject: $subject"
info "Issuer:  $issuer"

# Dates
not_before=$(echo "$cert_info" | openssl x509 -noout -startdate 2>/dev/null | sed 's/^notBefore=//')
not_after=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | sed 's/^notAfter=//')
ok "Valid from: $not_before"
ok "Expires:    $not_after"

# Check expiry
now_epoch=$(date +%s)
exp_epoch=$(date -d "$not_after" +%s 2>/dev/null) || \
    exp_epoch=$(date -j -f "%b %d %H:%M:%S %Y %Z" "$not_after" +%s 2>/dev/null) || \
    exp_epoch=""
if [ -z "$exp_epoch" ]; then
    warn "Could not parse expiry date: $not_after"
else
    days_left=$(( (exp_epoch - now_epoch) / 86400 ))
    if [ $days_left -lt 0 ]; then
        fail "EXPIRED $((-days_left)) days ago!"
    elif [ $days_left -lt 7 ]; then
        fail "Expires in $days_left days — renew NOW"
    elif [ $days_left -lt 30 ]; then
        warn "Expires in $days_left days — renew soon"
    else
        ok "Expires in $days_left days"
    fi
fi

# SAN
sans=$(echo "$cert_info" | openssl x509 -noout -text 2>/dev/null | grep -A1 "Subject Alternative Name" | tail -1 | sed 's/DNS://g; s/,/ /g; s/^ *//')
[ -n "$sans" ] && info "SANs: $sans"

# Key size
key_size=$(echo "$cert_info" | openssl x509 -noout -text 2>/dev/null | grep "Public-Key:" | grep -o '[0-9]*')
if [ -n "$key_size" ]; then
    if [ "$key_size" -ge 4096 ]; then
        ok "Key size: ${key_size}-bit (excellent)"
    elif [ "$key_size" -ge 2048 ]; then
        ok "Key size: ${key_size}-bit (good)"
    else
        warn "Key size: ${key_size}-bit (weak)"
    fi
fi

# Signature algorithm
sig_algo=$(echo "$cert_info" | openssl x509 -noout -text 2>/dev/null | grep "Signature Algorithm:" | head -1 | awk '{print $NF}')
if echo "$sig_algo" | grep -qi "sha256\|sha384\|sha512"; then
    ok "Signature: $sig_algo"
elif echo "$sig_algo" | grep -qi "sha1\|md5"; then
    fail "Signature: $sig_algo (insecure)"
else
    info "Signature: $sig_algo"
fi

# --- Certificate chain ---
if [ -n "$CHAIN" ]; then
    section "Certificate Chain"
    chain=$(echo | openssl s_client -connect "$DOMAIN:$PORT" -servername "$DOMAIN" -showcerts 2>/dev/null | grep -E "^ [0-9]" | head -10)
    if [ -n "$chain" ]; then
        echo "$chain" | while IFS= read -r line; do
            info "$line"
        done
    else
        info "Single certificate (no chain)"
    fi

    # Verify
    verify=$(echo | openssl s_client -connect "$DOMAIN:$PORT" -servername "$DOMAIN" 2>/dev/null | grep "Verify return code:")
    if echo "$verify" | grep -q "ok"; then
        ok "Chain verification: OK"
    else
        warn "Chain verification: $verify"
    fi
fi

# --- TLS versions ---
if [ -n "$TLS_TEST" ]; then
    section "TLS Version Support"
    for ver in tls1 tls1_1 tls1_2 tls1_3; do
        result=$(echo | openssl s_client -connect "$DOMAIN:$PORT" -servername "$DOMAIN" -"$ver" 2>&1)
        if echo "$result" | grep -q "BEGIN CERTIFICATE\|Protocol.*TLSv"; then
            ok "$ver supported"
        else
            info "$ver NOT supported"
        fi
    done
fi

# --- Cipher suites ---
section "Cipher Suites"
ciphers=$(echo | openssl s_client -connect "$DOMAIN:$PORT" -servername "$DOMAIN" 2>/dev/null | grep "Cipher    :" | awk '{print $NF}')
[ -n "$ciphers" ] && ok "Negotiated: $ciphers"

# --- HSTS check ---
section "Security Headers"
headers=$(curl -sI -m 5 "https://$DOMAIN" 2>/dev/null)

if echo "$headers" | grep -qi "strict-transport-security"; then
    hsts=$(echo "$headers" | grep -i "strict-transport-security" | head -1)
    ok "HSTS: $hsts"
else
    warn "HSTS: Not set"
fi

if echo "$headers" | grep -qi "x-content-type-options"; then
    ok "X-Content-Type-Options: set"
else
    warn "X-Content-Type-Options: missing"
fi

if echo "$headers" | grep -qi "x-frame-options"; then
    ok "X-Frame-Options: set"
else
    warn "X-Frame-Options: missing"
fi

echo ""
echo -e "${GREEN}[+] SSL check complete.${NC}"
