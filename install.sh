#!/data/data/com.termux/files/usr/bin/bash
set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

clear
echo -e "${CYAN}
   __  ___              __   ______       ____
  /  |/  /__  _______  / /  / __/ /  ___ / / /
 / /|_/ / _ \/ __/ _ \/ _ \_\ \/ _ \/ -_) / /
/_/  /_/\___/_/ / .__/_//_/___/_//_/\__/_/_/
               /_/
${RESET}"

echo -e "${GREEN}
A sleek Termux theme with a smart prompt,
syntax highlighting, a dynamic animated
banner, and built-in security toolkit.
${RESET}"

rm -rf $PREFIX/etc/motd
DEPS=(git tte fish eza bat starship nmap curl python)

echo -e "${CYAN}[*] Checking dependencies...${RESET}"
for p in "${DEPS[@]}"; do
  if ! command -v "$p" >/dev/null 2>&1; then
    echo -e "${GREEN}[+] Installing $p${RESET}"
    apt install -y "$p"
  fi
done

TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
DIR="$TMPDIR/MorphShell"
rm -rf "$DIR"

echo -e "${CYAN}[*] Cloning MorphShell...${RESET}"
git clone -q https://github.com/termuxvoid/MorphShell "$DIR"

ASSETS="$DIR/assets"
TOOLS="$DIR/tools"

if [ "$(basename "$SHELL")" != "fish" ]; then
  echo -e "${GREEN}[*] Switching shell to fish${RESET}"
  chsh -s fish
fi

chsh -s fish

read -rp "Enter prompt name [MorphShell]: " NAME
NAME="${NAME:-MorphShell}"

mkdir -p ~/.config/fish ~/.config ~/.termux ~/.local/bin

# --- MorphShell theme ---
cp "$ASSETS/config.fish" ~/.config/fish/config.fish
cp "$ASSETS/font.ttf" "$ASSETS/colors.properties" ~/.termux
sed "s/user-name/$NAME/g" "$ASSETS/starship.toml" > ~/.config/starship.toml
sed "s/user-name/$NAME/g" "$ASSETS/motd" > ~/.config/morphshell

# --- Security toolkit ---
echo -e "${CYAN}[*] Installing security toolkit...${RESET}"

chmod +x "$TOOLS"/*.sh "$TOOLS"/lib/*.sh 2>/dev/null

# Symlink tools to ~/.local/bin
for tool in "$TOOLS"/*.sh; do
    name=$(basename "$tool" .sh)
    ln -sf "$tool" ~/.local/bin/tk-"$name"
done

# Add toolkit PATH to fish config
if ! grep -q 'tk-' ~/.config/fish/config.fish 2>/dev/null; then
    cat >> ~/.config/fish/config.fish << 'FISH_TOOLS'

# --- Security Toolkit ---
set -gx PATH $HOME/.local/bin $PATH
alias scan='tk-scanner'
alias recon='tk-recon'
alias audit='tk-audit'
alias ssl='tk-ssl-check'
alias hashid='tk-hash-id'
alias logs='tk-log-analyzer'
alias vuln='tk-vuln-check'
FISH_TOOLS
fi

# Fix /tmp for Termux
mkdir -p ~/tmp
if ! grep -q 'TMPDIR' ~/.bashrc 2>/dev/null; then
    echo 'export TMPDIR=$HOME/tmp TMP=$HOME/temp TEMP=$HOME/tmp TEMPDIR=$HOME/tmp' >> ~/.bashrc
fi

echo -e "${GREEN}[✓] MorphShell + Security Toolkit installed.${RESET}"
echo ""
echo -e "${YELLOW}Security commands:${RESET}"
echo "  scan <target>     Network port scanner"
echo "  recon <target>    OSINT reconnaissance"
echo "  audit             Password strength auditor"
echo "  ssl <domain>      SSL/TLS certificate checker"
echo "  hashid <hash>     Hash identification"
echo "  logs              Auth log analyzer"
echo "  vuln <target>     Web vulnerability scanner"
echo ""
echo -e "${GREEN}Restart Termux to see the banner.${RESET}"
