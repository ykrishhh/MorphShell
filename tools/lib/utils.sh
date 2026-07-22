#!/data/data/com.termux/files/usr/bin/bash
# Shared utility functions for Termux Security Toolkit

# Check if command exists
has_cmd() { command -v "$1" > /dev/null 2>&1; }

# Check root
is_root() { [ "$(id -u)" -eq 0 ]; }

need_root() {
    if ! is_root; then
        echo -e "${RED}[!] This tool requires root. Run: tsu${NC}"
        exit 1
    fi
}

# Confirm action
confirm() {
    read -rp "$(echo -e "${YELLOW}$1 [y/N]: ${NC}")" choice
    case "$choice" in
        [yY][eE][sS]|[yY]) return 0 ;;
        *) return 1 ;;
    esac
}

# Validate IP address
is_ip() { echo "$1" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; }

# Validate domain
is_domain() { echo "$1" | grep -qE '^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$'; }

# Normalize URL (add https if missing)
normalize_url() {
    local url="$1"
    echo "$url" | grep -q '^https\?://' || url="https://$url"
    echo "$url"
}

# Extract domain from URL
url_to_domain() {
    echo "$1" | sed 's|https\?://||;s|/.*||;s|:.*||'
}

# Check if port is open (timeout 2s)
port_open() {
    (echo > /dev/tcp/"$1"/"$2") 2>/dev/null
}

# Get public IP
my_ip() {
    curl -s --max-time 5 ifconfig.me 2>/dev/null || \
    curl -s --max-time 5 icanhazip.com 2>/dev/null || \
    echo "unknown"
}

# Save output to file if -o was specified
save_output() {
    local file="$1"
    local content="$2"
    [ -n "$file" ] && echo "$content" >> "$file"
}

# Timestamp
timestamp() { date "+%Y-%m-%d %H:%M:%S"; }

# Check Termux
is_termux() { [ -d "/data/data/com.termux" ]; }

# Get Termux data dir
termux_data() { echo "/data/data/com.termux/files"; }
