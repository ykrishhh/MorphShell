#!/data/data/com.termux/files/usr/bin/bash
# tk-dir-brute — Directory & file brute-forcer for Termux

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") <target> [options]"
    echo ""
    echo "Options:"
    echo "  -w <wordlist>    Custom wordlist (default: built-in)"
    echo "  -x <ext>         Extensions to try (e.g. php,html,txt)"
    echo "  -s               Show only 200 OK responses"
    echo "  -o <file>        Save results"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") https://example.com"
    echo "  $(basename "$0") https://example.com -x php,html -s"
    exit 1
}

[ $# -lt 1 ] && usage

TARGET=""
EXTENSIONS=""
SHOW_OK=""
OUTPUT=""
CUSTOM_WL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -w) CUSTOM_WL="$2"; shift 2 ;;
        -x) EXTENSIONS="$2"; shift 2 ;;
        -s) SHOW_OK=1; shift ;;
        -o) OUTPUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) TARGET="$1"; shift ;;
    esac
done

[ -z "$TARGET" ] && { fail "No target"; usage; }

BUILTIN_PATHS=(
    admin login dashboard api docs swagger graphql
    wp-admin wp-login.php wp-content xmlrpc.php
    .env .git .git/config .htaccess robots.txt sitemap.xml
    backup config db database sql phpinfo.php info.php
    server-status server-info .svn/entries .DS_Store
    css js img images assets static media uploads
    cgi-bin bin etc var tmp temp
    test testing staging dev development
    api/v1 api/v2 api/v3 v1 v2 v3
    login.php register.php signup.php
    user users profile account settings
    file files download upload export import
    status health check ping metrics
)

header "Directory Brute — $TARGET"

count=0
found=0

brute() {
    local path="$1"
    local url="$TARGET/$path"
    local status=$(curl -s -o /dev/null -w "%{http_code}" -m 5 "$url" 2>/dev/null)

    case "$status" in
        200|301|302|403)
            if [ -n "$SHOW_OK" ] && [ "$status" != "200" ]; then
                return
            fi
            case "$status" in
                200) ok "200  $url" ;;
                301|302) info "[$status] $url → redirect" ;;
                403) warn "403  $url (forbidden)" ;;
            esac
            [ -n "$OUTPUT" ] && echo "$status $url" >> "$OUTPUT"
            found=$((found + 1))
            ;;
    esac
    count=$((count + 1))
}

if [ -n "$CUSTOM_WL" ] && [ -f "$CUSTOM_WL" ]; then
    section "Using wordlist: $CUSTOM_WL"
    while IFS= read -r word; do
        [ -z "$word" ] && continue
        brute "$word"
        if [ -n "$EXTENSIONS" ]; then
            IFS=',' read -ra EXTS <<< "$EXTENSIONS"
            for ext in "${EXTS[@]}"; do
                brute "$word.$ext"
            done
        fi
    done < "$CUSTOM_WL"
else
    section "Using built-in wordlist (${#BUILTIN_PATHS[@]} paths)"
    for word in "${BUILTIN_PATHS[@]}"; do
        brute "$word"
        if [ -n "$EXTENSIONS" ]; then
            IFS=',' read -ra EXTS <<< "$EXTENSIONS"
            for ext in "${EXTS[@]}"; do
                brute "$word.$ext"
            done
        fi
    done
fi

echo ""
ok "Checked $count paths, found $found results"
[ -n "$OUTPUT" ] && ok "Results saved to $OUTPUT"
