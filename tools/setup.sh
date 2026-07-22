#!/data/data/com.termux/files/usr/bin/bash
# setup.sh — One-shot Termux security environment setup
# Installs everything you need for pentesting on Android.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Termux Security Toolkit — Setup       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}[!] This script is for Termux on Android.${NC}"
    exit 1
fi

step() { echo -e "\n${YELLOW}[*] $1${NC}"; }
ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
has_cmd() { command -v "$1" > /dev/null 2>&1; }

# --- 1. Fix /tmp ---
step "Fixing /tmp directory"
mkdir -p ~/tmp
if ! grep -q 'TMPDIR' ~/.bashrc 2>/dev/null; then
    echo 'export TMPDIR=$HOME/tmp TMP=$HOME/tmp TEMP=$HOME/tmp TEMPDIR=$HOME/tmp' >> ~/.bashrc
    ok "Added TMPDIR exports to ~/.bashrc"
else
    ok "TMPDIR already configured"
fi
export TMPDIR=$HOME/tmp TMP=$HOME/tmp TEMP=$HOME/tmp TEMPDIR=$HOME/tmp

# --- 2. Update packages ---
step "Updating package lists"
pkg update -y > /dev/null 2>&1
ok "Package lists updated"

# --- 3. Install core tools ---
step "Installing core security tools"
pkg install -y nmap curl python git hydra > /dev/null 2>&1
ok "nmap, curl, python, git, hydra installed"

# --- 4. Install optional tools ---
step "Installing optional tools"
for pkg in nikto sqlmap john moreutils tree; do
    pkg install -y "$pkg" > /dev/null 2>&1 && ok "$pkg" || warn "$pkg not available"
done

# --- 5. Fix Nikto ---
step "Fixing Nikto"
if has_cmd nikto; then
    # IO::Socket::SSL
    if ! perl -e "use IO::Socket::SSL" 2>/dev/null; then
        cpan -T IO::Socket::SSL > /dev/null 2>&1
        ok "IO::Socket::SSL installed"
    else
        ok "IO::Socket::SSL already installed"
    fi

    # nikto.conf
    nikto_conf="/data/data/com.termux/files/usr/share/nikto/program/nikto.conf"
    nikto_default="/data/data/com.termux/files/usr/share/nikto/program/nikto.conf.default"
    if [ ! -f "$nikto_conf" ] && [ -f "$nikto_default" ]; then
        cp "$nikto_default" "$nikto_conf"
        sed -i 's|TEMPLATES=/usr/share/nikto/program/templates|TEMPLATES=/data/data/com.termux/files/usr/share/nikto/program/templates|' "$nikto_conf"
        ok "nikto.conf created from default"
    else
        ok "nikto.conf exists"
    fi

    # Output dir
    mkdir -p ~/nikto-output
    ok "nikto-output directory ready"
else
    warn "nikto not installed — skipping fix"
fi

# --- 6. Python setup ---
step "Setting up Python"
pip install --upgrade pip > /dev/null 2>&1
pip install requests > /dev/null 2>&1
ok "pip updated, requests installed"

# --- 7. Install toolkit ---
step "Installing toolkit commands"
chmod +x install.sh scanner.sh recon.sh audit.sh ssl-check.sh hash-id.sh log-analyzer.sh vuln-check.sh setup.sh
./install.sh
ok "Tool commands installed (tk-scanner, tk-recon, tk-audit, tk-ssl-check, tk-hash-id, tk-log-analyzer, tk-vuln-check)"

# --- 8. Wordlist ---
step "Downloading wordlist"
mkdir -p ~/.local/share/wordlists
if [ ! -f ~/.local/share/wordlists/rockyou.txt ]; then
    warn "Download rockyou.txt manually: $(basename "$0") -w"
else
    ok "rockyou.txt already present"
fi

# --- 9. Optional: root access ---
step "Root access (optional)"
if has_cmd tsu; then
    ok "tsu already installed"
else
    warn "Install tsu for root: pkg install tsu"
fi

# --- 10. PATH ---
step "Updating PATH"
if ! grep -q '.local/bin' ~/.bashrc 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    ok "Added ~/.local/bin to PATH"
else
    ok "PATH already configured"
fi

# --- Done ---
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup Complete!                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "Run 'source ~/.bashrc' or restart your terminal."
echo ""
echo "Available commands:"
echo "  tk-scanner <target>       Network port scanner"
echo "  tk-recon <target>         OSINT reconnaissance"
echo "  tk-audit                  Password auditor"
echo "  tk-ssl-check <domain>     SSL/TLS checker"
echo "  tk-hash-id <hash>         Hash identifier"
echo "  tk-log-analyzer           Auth log analyzer"
echo "  tk-vuln-check <target>    Web vulnerability scanner"
echo ""
echo "Docs:"
echo "  TROUBLESHOOTING.md        Real problems we hit"
echo "  CHEATSHEET.md             Quick reference commands"
echo "  README.md                 Full documentation"
