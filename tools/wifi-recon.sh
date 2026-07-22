#!/data/data/com.termux/files/usr/bin/bash
# tk-wifi-recon — WiFi network scanner for Termux
# Requires root (tsu) for monitor mode operations.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "$SCRIPT_DIR/lib/colors.sh"

usage() {
    echo "Usage: $(basename "$0") [options]"
    echo ""
    echo "Options:"
    echo "  -i <iface>      Interface (default: wlan0)"
    echo "  -s              Scan mode (list networks)"
    echo "  -m              Monitor mode (requires root)"
    echo "  -c <channel>    Lock to channel"
    echo ""
    echo "Examples:"
    echo "  $(basename "$0") -s                # scan nearby networks"
    echo "  $(basename "$0") -m                # enable monitor mode"
    echo "  $(basename "$0") -i wlan1 -s       # scan on specific interface"
    exit 1
}

IFACE="wlan0"
MODE="scan"
CHANNEL=""

while [ $# -gt 0 ]; do
    case "$1" in
        -i) IFACE="$2"; shift 2 ;;
        -s) MODE="scan"; shift ;;
        -m) MODE="monitor"; shift ;;
        -c) CHANNEL="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) shift ;;
    esac
done

if ! has_cmd iw && ! has_cmd iwlist; then
    fail "iw or iwlist required. Install: pkg install iw"
    exit 1
fi

header "WiFi Recon — $IFACE"

case "$MODE" in
    scan)
        section "Scanning networks"
        if has_cmd iw; then
            iw dev "$IFACE" scan 2>/dev/null | awk '
                /^BSS / { mac=$2; gsub(/\(.*/, "", mac) }
                /SSID:/ { ssid=$2 }
                /signal:/ { signal=$2" "$3 }
                /freq:/ { freq=$2 }
                /capability:/ {
                    security=""
                    if ($0 ~ /Privacy/) security="WEP"
                    if ($0 ~ /WPA/) security="WPA"
                    if ($0 ~ /WPA2/) security="WPA2"
                }
                /RSN:/ { security="WPA2+" }
                /^BSS / || /^[^B]/ {
                    if (mac != "" && ssid != "") {
                        printf "%-20s %-30s %-8s %s\n", mac, ssid, signal, security
                    }
                }
                END { if (mac != "" && ssid != "") printf "%-20s %-30s %-8s %s\n", mac, ssid, signal, security }
            '
        elif has_cmd iwlist; then
            iwlist "$IFACE" scan 2>/dev/null | awk -F': ' '
                /Cell/ { mac=$2 }
                /ESSID/ { gsub(/"/, "", $2); ssid=$2 }
                /Signal/ { signal=$2 }
                /Encryption/ { enc=$2 }
                /Cell/ && mac != "" && ssid != "" {
                    printf "%-20s %-30s %-8s %s\n", mac, ssid, signal, enc
                }
            '
        fi
        ;;
    monitor)
        section "Enabling monitor mode"
        if ! has_cmd tsu; then
            fail "Root required. Install: pkg install tsu"
            exit 1
        fi
        info "Run: tsu"
        info "Then: ip link set $IFACE down"
        info "      iw dev $IFACE set type monitor"
        info "      ip link set $IFACE up"
        info "      iw dev $IFACE set channel $CHANNEL" 2>/dev/null
        ;;
esac

echo ""
ok "Done."