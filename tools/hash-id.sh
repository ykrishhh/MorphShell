#!/data/data/com.termux/files/usr/bin/bash
# hash-id — Hash identification and cracking helper
# Identifies hash type by length and charset, suggests attack methods.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Modes:"
    echo "  (no args)          Interactive — enter hashes to identify"
    echo "  -f <file>          Identify hashes from file (one per line)"
    echo "  -c <hash>          Crack hash with wordlist"
    echo "  -w                 Download wordlist"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                    # interactive"
    echo "  $(basename "$0") -c 5f4dcc3b5aa765d61d8327deb882cf99 -d rockyou.txt"
    echo "  $(basename "$0") -w                 # get wordlist"
    exit 1
}

identify_hash() {
    local hash="$1"
    local len=${#hash}
    local types=()

    # Check charset
    local is_hex=0
    local is_b64=0
    local is_num=0

    echo "$hash" | grep -qE '^[0-9a-fA-F]+$' && is_hex=1
    echo "$hash" | grep -qE '^[A-Za-z0-9+/=]+$' && is_b64=1
    echo "$hash" | grep -qE '^[0-9]+$' && is_num=1

    # Length-based identification
    case $len in
        32)
            [ $is_hex -eq 1 ] && types+=("MD5" "NTLM" "MD4")
            ;;
        40)
            [ $is_hex -eq 1 ] && types+=("SHA-1" "MySQL4.1+")
            ;;
        64)
            [ $is_hex -eq 1 ] && types+=("SHA-256" "SHA3-256")
            ;;
        96)
            [ $is_hex -eq 1 ] && types+=("SHA-384")
            ;;
        128)
            [ $is_hex -eq 1 ] && types+=("SHA-512" "SHA3-512")
            ;;
        16)
            [ $is_hex -eq 1 ] && types+=("MD5 (half)" "MySQL323")
            ;;
        24)
            [ $is_b64 -eq 1 ] && types+=("MD5 (base64)" "DES")
            ;;
        41)
            [ $is_hex -eq 1 ] && types+=("MD5 crypt ($1$)")
            ;;
        60)
            [ $is_hex -eq 1 ] && types+=("bcrypt" "SHA-512 crypt")
            ;;
        127)
            types+=("bcrypt ($2b$)")
            ;;
        34)
            echo "$hash" | grep -q '^\$2[aby]\$' && types+=("bcrypt")
            ;;
        256)
            types+=("Argon2 (raw)")
            ;;
    esac

    # Prefix-based identification (append, don't overwrite length-based)
    echo "$hash" | grep -q '^\$2[aby]\$' && types+=("\$2a\$ bcrypt" "\$2b\$ bcrypt")
    echo "$hash" | grep -q '^\$2y\$' && types+=("\$2y\$ bcrypt")
    echo "$hash" | grep -q '^\$1\$' && types+=("MD5 crypt (\$1\$)")
    echo "$hash" | grep -q '^\$5\$' && types+=("SHA-256 crypt (\$5\$)")
    echo "$hash" | grep -q '^\$6\$' && types+=("SHA-512 crypt (\$6\$)")
    echo "$hash" | grep -q '^\$argon2' && types+=("Argon2")
    echo "$hash" | grep -q '^\$pbkdf2' && types+=("PBKDF2")
    echo "$hash" | grep -qE '^[a-f0-9]{32}:[a-f0-9]{32}$' && types+=("NTLM (LM:NT)")
    echo "$hash" | grep -q '^[0-9]\{1,2\}\$' && types+=("Django PBKDF2")

    # Output
    echo -e "${CYAN}Hash:${NC}     $hash"
    echo -e "${CYAN}Length:${NC}   $len characters"

    if [ ${#types[@]} -gt 0 ]; then
        echo -e "${CYAN}Possible:${NC}"
        for t in "${types[@]}"; do
            ok "$t"
        done
    else
        warn "Unknown hash type"
    fi

    # Suggest attack
    echo -e "${CYAN}Attack:${NC}"
    if [ $is_hex -eq 1 ] && [ $len -le 40 ]; then
        info "Try: hashcat -m <mode> hash.txt wordlist.txt"
        info "Or:  john --wordlist=rockyou.txt hash.txt"
    elif [ $len -gt 40 ]; then
        info "Slow hash — use GPU (hashcat) or wordlist-only (john)"
    fi
    echo ""
}

crack_hash() {
    local hash="$1"
    local wordlist="$2"

    [ -z "$wordlist" ] || [ ! -f "$wordlist" ] && {
        echo -e "${RED}[!] Wordlist not found: $wordlist${NC}"
        echo "Run: $(basename "$0") -w to download one"
        exit 1
    }

    header "Cracking Hash"
    info "Hash: $hash"
    info "Wordlist: $wordlist ($(wc -l < "$wordlist") words)"
    echo ""

    # Try with python hashlib for common algorithms
    HASH="$hash" WORDLIST="$wordlist" python3 -c "
import hashlib, sys, os

target = os.environ['HASH']
wordlist = os.environ['WORDLIST']

algorithms = {
    'md5': hashlib.md5,
    'sha1': hashlib.sha1,
    'sha256': hashlib.sha256,
    'sha512': hashlib.sha512,
}

with open(wordlist, errors='ignore') as f:
    for i, line in enumerate(f):
        word = line.strip()
        if not word:
            continue
        for name, algo in algorithms.items():
            if algo(word.encode()).hexdigest() == target:
                print(f'\033[0;32m[+] FOUND: {word}\033[0m (algorithm: {name})')
                sys.exit(0)
        if i % 100000 == 0 and i > 0:
            print(f'  Checked {i} words...', end='\r')

print('\033[0;31m[-] Not found in wordlist.\033[0m')
" 2>/dev/null
}

download_wordlist() {
    mkdir -p ~/.local/share/wordlists
    if [ -f ~/.local/share/wordlists/rockyou.txt ]; then
        ok "Wordlist already at ~/.local/share/wordlists/rockyou.txt"
        return
    fi

    info "Downloading rockyou.txt..."
    curl -sL "https://github.com/danielmiessler/SecLists/raw/master/Passwords/Leaked-Databases/rockyou.txt.tar.gz" -o /tmp/rockyou.tar.gz 2>/dev/null
    if [ -f /tmp/rockyou.tar.gz ]; then
        tar xzf /tmp/rockyou.tar.gz -C ~/.local/share/wordlists/ 2>/dev/null
        rm -f /tmp/rockyou.tar.gz
        ok "Saved to ~/.local/share/wordlists/rockyou.txt"
    else
        warn "Download failed. Generating small wordlist..."
        curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/top-20-common-SSH-passwords.txt" -o ~/.local/share/wordlists/common.txt 2>/dev/null
        ok "Common passwords saved to ~/.local/share/wordlists/common.txt"
    fi
}

# --- Main ---
MODE="identify"
HASH=""
WORDLIST=""
FILE=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f) MODE="file"; FILE="$2"; shift 2 ;;
        -c) MODE="crack"; HASH="$2"; shift 2 ;;
        -d) WORDLIST="$2"; shift 2 ;;
        -w) download_wordlist; exit 0 ;;
        -h|--help) usage ;;
        *) HASH="$1"; MODE="identify-single"; shift ;;
    esac
done

case "$MODE" in
    identify|identify-single)
        if [ -n "$HASH" ]; then
            identify_hash "$HASH"
        else
            header "Hash Identifier"
            while true; do
                read -rp "Hash: " h
                [ -z "$h" ] && continue
                identify_hash "$h"
            done
        fi
        ;;
    file)
        [ -z "$FILE" ] || [ ! -f "$FILE" ] && { fail "File not found: $FILE"; exit 1; }
        header "Hash Identifier — File Mode"
        while IFS= read -r h; do
            [ -z "$h" ] && continue
            identify_hash "$h"
        done < "$FILE"
        ;;
    crack)
        [ -z "$HASH" ] && { fail "No hash specified"; usage; }
        [ -z "$WORDLIST" ] && WORDLIST="$HOME/.local/share/wordlists/rockyou.txt"
        crack_hash "$HASH" "$WORDLIST"
        ;;
esac
