#!/data/data/com.termux/files/usr/bin/bash
# tk-audit — Password strength auditor for Termux
# Checks passwords against common patterns and dictionaries.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Modes:"
    echo "  (no args)          Interactive — enter passwords to check"
    echo "  -f <file>          Check passwords from file (one per line)"
    echo "  -g                 Generate strong password"
    echo "  -w                 Download wordlist for Hydra"
    echo ""
    echo "Options:"
    echo "  -m <min>           Minimum length (default: 8)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0")                  # interactive"
    echo "  $(basename "$0") -f passwords.txt # check file"
    echo "  $(basename "$0") -g               # generate password"
    echo "  $(basename "$0") -w               # get wordlist"
    exit 1
}

MIN_LEN=8
MODE="interactive"
FILE=""
GENERATE=""
WORDLIST=""

while [ $# -gt 0 ]; do
    case "$1" in
        -f) MODE="file"; FILE="$2"; shift 2 ;;
        -g) MODE="generate"; shift ;;
        -w) MODE="wordlist"; shift ;;
        -m) MIN_LEN="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) shift ;;
    esac
done

check_password() {
    local pw="$1"
    local score=0
    local issues=""

    # Length
    local len=${#pw}
    if [ $len -ge 16 ]; then
        score=$((score + 3))
    elif [ $len -ge 12 ]; then
        score=$((score + 2))
    elif [ $len -ge $MIN_LEN ]; then
        score=$((score + 1))
    else
        issues="${issues}  ${RED}✗ Too short (${len} chars, min ${MIN_LEN})${NC}\n"
    fi

    # Uppercase
    echo "$pw" | grep -q '[A-Z]' && score=$((score + 1)) || issues="${issues}  ${YELLOW}✗ No uppercase letters${NC}\n"

    # Lowercase
    echo "$pw" | grep -q '[a-z]' && score=$((score + 1)) || issues="${issues}  ${YELLOW}✗ No lowercase letters${NC}\n"

    # Numbers
    echo "$pw" | grep -q '[0-9]' && score=$((score + 1)) || issues="${issues}  ${YELLOW}✗ No numbers${NC}\n"

    # Special chars
    echo "$pw" | grep -q '[^a-zA-Z0-9]' && score=$((score + 1)) || issues="${issues}  ${YELLOW}✗ No special characters${NC}\n"

    # Common patterns
    local lower=$(echo "$pw" | tr '[:upper:]' '[:lower:]')
    for pattern in "password" "123456" "qwerty" "abc123" "letmein" "admin" "welcome" "monkey" "dragon" "master" "login" "12345678" "1234567890"; do
        echo "$lower" | grep -q "$pattern" && {
            issues="${issues}  ${RED}✗ Contains common pattern: $pattern${NC}\n"
            score=$((score - 2))
            break
        }
    done

    # Sequential chars
    echo "$pw" | grep -qE '(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)' && {
        issues="${issues}  ${YELLOW}✗ Contains sequential characters${NC}\n"
        score=$((score - 1))
    }

    # Repeated chars
    echo "$pw" | grep -qE '(.)\1\1' && {
        issues="${issues}  ${YELLOW}✗ Contains repeated characters${NC}\n"
        score=$((score - 1))
    }

    # Score rating
    if [ $score -ge 6 ]; then
        rating="${GREEN}STRONG${NC}"
    elif [ $score -ge 4 ]; then
        rating="${YELLOW}MODERATE${NC}"
    elif [ $score -ge 2 ]; then
        rating="${RED}WEAK${NC}"
    else
        rating="${RED}VERY WEAK${NC}"
    fi

    # Brute force estimate
    local charset=0
    echo "$pw" | grep -q '[a-z]' && charset=$((charset + 26))
    echo "$pw" | grep -q '[A-Z]' && charset=$((charset + 26))
    echo "$pw" | grep -q '[0-9]' && charset=$((charset + 10))
    echo "$pw" | grep -q '[^a-zA-Z0-9]' && charset=$((charset + 33))

    echo -e "${CYAN}Password:${NC} $(echo "$pw" | sed 's/./●/g')"
    echo -e "${CYAN}Rating:${NC}   $rating (score: $score/7)"
    echo -e "${CYAN}Length:${NC}   $len characters"
    [ -n "$issues" ] && echo -e "$issues"
    echo ""
}

generate_password() {
    local len=${1:-20}
    local pw=""
    local chars='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*'

    # Ensure at least one of each type
    pw+=$(echo 'abcdefghijklmnopqrstuvwxyz' | fold -w1 | shuf | head -1)
    pw+=$(echo 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' | fold -w1 | shuf | head -1)
    pw+=$(echo '0123456789' | fold -w1 | shuf | head -1)
    pw+=$(echo '!@#$%^&*' | fold -w1 | shuf | head -1)

    # Fill rest randomly
    for i in $(seq 1 $((len - 4))); do
        pw+=$(echo "$chars" | fold -w1 | shuf | head -1)
    done

    # Shuffle
    pw=$(echo "$pw" | fold -w1 | shuf | tr -d '\n')
    echo "$pw"
}

download_wordlist() {
    echo -e "${YELLOW}[*] Downloading rockyou.txt wordlist...${NC}"
    mkdir -p ~/.local/share/wordlists

    if [ -f ~/.local/share/wordlists/rockyou.txt ]; then
        echo -e "${GREEN}[+] Wordlist already exists at ~/.local/share/wordlists/rockyou.txt${NC}"
        return
    fi

    # Try common sources
    curl -sL "https://github.com/danielmiessler/SecLists/raw/master/Passwords/Leaked-Databases/rockyou.txt.tar.gz" -o /tmp/rockyou.tar.gz 2>/dev/null
    if [ -f /tmp/rockyou.tar.gz ]; then
        tar xzf /tmp/rockyou.tar.gz -C ~/.local/share/wordlists/ 2>/dev/null
        rm -f /tmp/rockyou.tar.gz
        echo -e "${GREEN}[+] Wordlist saved to ~/.local/share/wordlists/rockyou.txt${NC}"
    else
        # Fallback: generate a smaller list
        echo -e "${YELLOW}[!] Could not download rockyou. Generating common passwords list...${NC}"
        curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Passwords/Common-Credentials/top-20-common-SSH-passwords.txt" -o ~/.local/share/wordlists/common.txt 2>/dev/null
        echo -e "${GREEN}[+] Common passwords saved to ~/.local/share/wordlists/common.txt${NC}"
    fi
}

# --- Main ---

case "$MODE" in
    interactive)
        echo -e "${CYAN}[*] Termux Password Auditor${NC}"
        echo -e "${YELLOW}Enter passwords to check (Ctrl+C to exit)${NC}"
        echo ""
        while true; do
            read -rp "Password: " pw
            [ -z "$pw" ] && continue
            check_password "$pw"
        done
        ;;
    file)
        [ -z "$FILE" ] || [ ! -f "$FILE" ] && { echo -e "${RED}[!] File not found: $FILE${NC}"; exit 1; }
        echo -e "${CYAN}[*] Checking passwords in $FILE${NC}"
        echo ""
        while IFS= read -r pw; do
            [ -z "$pw" ] && continue
            check_password "$pw"
        done < "$FILE"
        ;;
    generate)
        echo -e "${CYAN}[*] Generated passwords:${NC}"
        for len in 16 20 24; do
            pw=$(generate_password $len)
            echo -e "  ${GREEN}$pw${NC}  ($len chars)"
        done
        echo ""
        echo "Copy one and use it!"
        ;;
    wordlist)
        download_wordlist
        ;;
esac
