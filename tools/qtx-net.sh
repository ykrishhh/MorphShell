#!/data/data/com.termux/files/usr/bin/bash
# qtx-net — Network speed & latency test
# ponytail: curl + ping, not speedtest-cli

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  -p <host>    Ping target (default: 8.8.8.8)"
    echo "  -s           Speed test (download + upload)"
    echo "  -l           Latency only (ping)"
    echo "  -a           All tests"
    echo "  -n <count>   Ping count (default: 10)"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -a           # all tests"
    echo "  $(basename "$0") -l           # ping only"
    echo "  $(basename "$0") -s           # speed only"
    echo "  $(basename "$0") -p 1.1.1.1   # ping Cloudflare"
    exit 1
}

HOST="8.8.8.8"
SPEED=""
LATENCY=""
ALL=""
PING_COUNT="10"

while [ $# -gt 0 ]; do
    case "$1" in
        -p) HOST="$2"; shift 2 ;;
        -s) SPEED=1; shift ;;
        -l) LATENCY=1; shift ;;
        -a) ALL=1; shift ;;
        -n) PING_COUNT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) shift ;;
    esac
done

[ -z "$SPEED" ] && [ -z "$LATENCY" ] && [ -z "$ALL" ] && ALL=1

# --- DNS resolution ---
section "DNS"
for server in 8.8.8.8 1.1.1.1 9.9.9.9; do
    time_ms=$(curl -s -o /dev/null -w "%{time_namelookup}" "http://$server" 2>/dev/null)
    if [ -n "$time_ms" ]; then
        ms=$(echo "$time_ms * 1000" | bc 2>/dev/null || echo "$time_ms")
        ok "$server — ${ms}ms resolve"
    fi
done
echo ""

# --- Latency ---
if [ -n "$LATENCY" ] || [ -n "$ALL" ]; then
    section "Latency — ping $HOST ($PING_COUNT packets)"

    if has_cmd ping; then
        ping -c "$PING_COUNT" -W 3 "$HOST" 2>/dev/null | tail -3
        echo ""

        # Stats
        stats=$(ping -c "$PING_COUNT" -W 3 "$HOST" 2>/dev/null | grep "rtt min/avg/max")
        if [ -n "$stats" ]; then
            avg=$(echo "$stats" | awk -F'/' '{print $5}')
            ok "Average latency: ${avg}ms"
        fi
    else
        # ponytail: fallback to curl timing
        warn "ping not available — using curl"
        for i in 1 2 3; do
            t=$(curl -s -o /dev/null -w "%{time_total}" "http://$HOST" 2>/dev/null)
            ms=$(echo "$t * 1000" | bc 2>/dev/null || echo "$t")
            info "Attempt $i: ${ms}ms"
        done
    fi
    echo ""
fi

# --- Speed test ---
if [ -n "$SPEED" ] || [ -n "$ALL" ]; then
    section "Download Speed"

    # ponytail: 10MB test file from cloudflare
    urls=(
        "https://speed.cloudflare.com/__down?bytes=10000000"
        "https://proof.ovh.net/files/10Mb.dat"
        "http://speedtest.tele2.net/10MB.zip"
    )

    for url in "${urls[@]}"; do
        info "Testing: $(echo "$url" | cut -d'/' -f3)"
        result=$(curl -s -w "\n%{speed_download}\n%{time_total}" -o /dev/null "$url" 2>/dev/null)
        speed=$(echo "$result" | tail -2 | head -1)
        time=$(echo "$result" | tail -1)

        if [ -n "$speed" ] && [ "$speed" != "0" ]; then
            mbps=$(echo "scale=2; $speed / 1048576" | bc 2>/dev/null || echo "$speed")
            ok "Download: ${mbps} MB/s (${time}s)"
            break
        fi
    done
    echo ""

    section "Upload Speed"
    # ponytail: upload 5MB to httpbin
    info "Testing upload to httpbin.org"
    result=$(curl -s -w "\n%{speed_upload}\n%{time_total}" -o /dev/null \
        -X POST -d "@/dev/urandom" --data-binary @/dev/urandom \
        -H "Content-Type: application/octet-stream" \
        "https://httpbin.org/post" 2>/dev/null)
    speed=$(echo "$result" | tail -2 | head -1)
    time=$(echo "$result" | tail -1)

    if [ -n "$speed" ] && [ "$speed" != "0" ]; then
        mbps=$(echo "scale=2; $speed / 1048576" | bc 2>/dev/null || echo "$speed")
        ok "Upload: ${mbps} MB/s (${time}s)"
    else
        warn "Upload test failed"
    fi
    echo ""
fi

# --- Public IP ---
section "Public IP"
ip=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || curl -s --max-time 5 icanhazip.com 2>/dev/null)
[ -n "$ip" ] && ok "$ip" || warn "Could not determine public IP"

echo ""
ok "Done."
