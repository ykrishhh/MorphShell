#!/data/data/com.termux/files/usr/bin/bash
set -e

RED='\033[1;31m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
RESET='\033[0m'

SKIP_DEPS=0
DO_UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --uninstall)   DO_UNINSTALL=1 ;;
    --skip-deps)   SKIP_DEPS=1 ;;
    --help|-h)
      echo "Usage: ./install.sh [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --uninstall    Remove all QTX components"
      echo "  --skip-deps    Skip dependency installation"
      echo "  -h, --help     Show this help"
      exit 0
      ;;
  esac
done

if [ "$DO_UNINSTALL" -eq 1 ]; then
  if [ -f tools/uninstall.sh ]; then
    bash tools/uninstall.sh
  elif [ -f ~/QTX/tools/uninstall.sh ]; then
    bash ~/QTX/tools/uninstall.sh
  else
    echo -e "${RED}Error: uninstall.sh not found. Run from QTX/ directory.${RESET}"
    exit 1
  fi
  exit 0
fi

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

# --- Dependencies ---
DEPS=(git tte fish eza bat starship nmap curl python)

if [ "$SKIP_DEPS" -eq 0 ]; then
  echo -e "${CYAN}[*] Checking dependencies...${RESET}"
  for p in "${DEPS[@]}"; do
    if ! command -v "$p" >/dev/null 2>&1; then
      echo -e "${GREEN}[+] Installing $p${RESET}"
      pkg install -y "$p" 2>/dev/null || apt install -y "$p" || {
        echo -e "${RED}[!] Failed to install $p — install manually: pkg install $p${RESET}"
        exit 1
      }
    fi
  done
else
  echo -e "${YELLOW}[*] Skipping dependency check (--skip-deps)${RESET}"
fi

# --- Clone repo ---
TMPDIR="${TMPDIR:-$HOME/tmp}"
mkdir -p "$TMPDIR"
DIR="$TMPDIR/QTX"
rm -rf "$DIR"

echo -e "${CYAN}[*] Cloning QTX...${RESET}"
git clone -q https://github.com/harry6e/QTX "$DIR" || {
  echo -e "${RED}[!] Failed to clone QTX repo${RESET}"
  exit 1
}

ASSETS="$DIR/assets"
TOOLS="$DIR/tools"

# --- Switch to fish ---
if [ "$(basename "$SHELL")" != "fish" ]; then
  echo -e "${GREEN}[*] Switching shell to fish${RESET}"
  chsh -s fish
fi

# --- Prompt name ---
read -rp "Enter prompt name [QTX]: " NAME
NAME="${NAME:-QTX}"

mkdir -p ~/.config/fish/completions ~/.config ~/.termux ~/.local/bin

# --- QTX theme ---
cp "$ASSETS/config.fish" ~/.config/fish/config.fish
cp "$ASSETS/font.ttf" "$ASSETS/colors.properties" ~/.termux
sed "s/user-name/$NAME/g" "$ASSETS/starship.toml" > ~/.config/starship.toml
sed "s/user-name/$NAME/g" "$ASSETS/motd" > ~/.config/qtx

# --- Install all tools ---
echo -e "${CYAN}[*] Installing security toolkit...${RESET}"

chmod +x "$TOOLS"/*.sh 2>/dev/null
chmod +x "$TOOLS"/lib/*.sh 2>/dev/null

INSTALLED=0
for tool in "$TOOLS"/*.sh; do
  [ -f "$tool" ] || continue
  name=$(basename "$tool" .sh)
  [ "$name" = "uninstall" ] && continue
  [ "$name" = "setup" ] && continue
  ln -sf "$tool" ~/.local/bin/tk-"$name"
  INSTALLED=$((INSTALLED + 1))
done
echo -e "${GREEN}  Symlinked $INSTALLED tools to ~/.local/bin/${RESET}"

# --- Fish completions ---
if [ -f "$DIR/completions/qtx.fish" ]; then
  cp "$DIR/completions/qtx.fish" ~/.config/fish/completions/
  echo -e "${GREEN}  Installed fish completions${RESET}"
else
  echo -e "${YELLOW}  No completions found, skipping${RESET}"
fi

# --- PATH and aliases ---
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
alias wifi='tk-wifi-recon'
alias dirbrute='tk-dir-brute'
alias nikto='tk-nikto-scan'
alias hunt='tk-qtx-hunt'
alias fm='tk-qtx-fm'
FISH_TOOLS
fi

# --- Fix /tmp for Termux ---
mkdir -p ~/tmp
if ! grep -q 'TMPDIR' ~/.bashrc 2>/dev/null; then
  echo 'export TMPDIR=$HOME/tmp TMP=$HOME/tmp TEMP=$HOME/tmp TEMPDIR=$HOME/tmp' >> ~/.bashrc
fi

# --- Success ---
echo -e "${GREEN}[✓] QTX + Security Toolkit installed!${RESET}"
echo ""
echo -e "${YELLOW}Available commands:${RESET}"
echo "  scan <target>     Network port scanner"
echo "  recon <target>    OSINT reconnaissance"
echo "  audit             Password strength auditor"
echo "  ssl <domain>      SSL/TLS certificate checker"
echo "  hashid <hash>     Hash identification"
echo "  logs              Auth log analyzer"
echo "  vuln <target>     Web vulnerability scanner"
echo "  wifi <target>     WiFi reconnaissance"
echo "  dirbrute <url>    Directory brute-force"
echo "  nikto <target>    Nikto web scanner"
echo ""
echo -e "${GREEN}Restart Termux to see the banner.${RESET}"
