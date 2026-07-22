# Termux Security Cheatsheet

Quick commands for common security tasks on Termux.

---

## Setup (run once)

```bash
# Full environment setup
./setup.sh

# Or manual:
pkg update && pkg install -y nmap curl python git hydra sqlmap nikto
mkdir -p ~/tmp ~/.local/bin
echo 'export TMPDIR=$HOME/tmp TMP=$HOME/tmp TEMP=$HOME/tmp' >> ~/.bashrc

# Nikto fix
cpan -T IO::Socket::SSL
cp /data/data/com.termux/files/usr/share/nikto/program/nikto.conf.default \
   /data/data/com.termux/files/usr/share/nikto/program/nikto.conf

# Root access (optional)
pkg install tsu
```

---

## Network Scanning

```bash
# Quick port scan
nmap -sT <target>

# Stealth scan (needs root/tsu)
nmap -sS -T4 <target>

# Full scan with scripts
nmap -sC -sV -O <target>

# Scan specific ports
nmap -p 80,443,8080,3000 <target>

# UDP scan (slow, needs root)
nmap -sU --top-ports 20 <target>

# Output to file
nmap -oN scan.txt -oX scan.xml <target>

# Using our tool
./scanner.sh <target> -T          # quick
./scanner.sh <target> -s -A       # stealth + aggressive
```

---

## Recon / OSINT

```bash
# DNS lookup
dig <domain> A
dig <domain> MX
dig <domain> ANY

# Reverse DNS
dig -x <ip>

# HTTP headers
curl -sI https://<target>

# Technology detection
curl -sI https://<target> | grep -iE 'server|x-powered|x-generator'

# Subdomain enumeration
for sub in www mail ftp vpn api cdn blog dev staging admin; do
    dig +short $sub.<domain> A
done

# Whois
whois <domain>

# SSL certificate info
echo | openssl s_client -connect <domain>:443 2>/dev/null | openssl x509 -noout -text

# Using our tool
./recon.sh <target> -d            # deep recon
```

---

## Vulnerability Scanning

```bash
# Nikto web scanner
nikto -h <target> -output ~/nikto-output/scan.txt

# Nikto full
nikto -h <target> -C all -output ~/nikto-output/scan.txt

# Nikto stealth
nikto -h <target> -Tuning 1234567890 -nointeractive

# SQLMap
sqlmap -u "https://<target>/page?id=1" --batch
sqlmap -u "https://<target>/page?id=1" --dbs --batch

# Using our tool
./vuln-check.sh <target>          # web vulns
./ssl-check.sh <target>           # SSL/TLS check
```

---

## Password Attacks

```bash
# Hydra SSH brute force
hydra -l admin -P /path/to/wordlist.txt ssh://<target>

# Hydra HTTP form
hydra -l admin -P wordlist.txt <target> http-post-form "/login:user=^USER^&pass=^PASS^:F=Login failed"

# Hydra FTP
hydra -l admin -P wordlist.txt ftp://<target>

# Wordlist location
ls ~/.local/share/wordlists/

# Using our tool
./audit.sh -w                     # download wordlist
./audit.sh -g                     # generate strong password
```

---

## Hash Cracking

```bash
# Identify hash
./hash-id.sh -c <hash>

# John the Ripper
john --wordlist=rockyou.txt hash.txt
john --show hash.txt

# Hashcat (if available)
hashcat -m 0 hash.txt wordlist.txt      # MD5
hashcat -m 100 hash.txt wordlist.txt    # SHA-1
hashcat -m 1400 hash.txt wordlist.txt   # SHA-256

# Python quick crack
python3 -c "
import hashlib
target = '<hash>'
with open('wordlist.txt') as f:
    for line in f:
        word = line.strip()
        if hashlib.md5(word.encode()).hexdigest() == target:
            print(f'Found: {word}')
            break
"
```

---

## Web Analysis

```bash
# Robots.txt
curl -s https://<target>/robots.txt

# Sitemap
curl -s https://<target>/sitemap.xml

# Wayback Machine
curl -s "https://web.archive.org/web/*/<target>" | grep -oP 'href="/web/\K[^"]+' | head -20

# JavaScript analysis
curl -s https://<target> | grep -oP 'src="[^"]*\.js"' | head -10

# Common paths
for path in /admin /login /api /swagger /graphql /.env /.git /wp-admin; do
    status=$(curl -s -o /dev/null -w "%{http_code}" https://<target>$path)
    [ "$status" != "404" ] && echo "$path → $status"
done
```

---

## WiFi (requires root/tsu)

```bash
# Put interface in monitor mode
tsu
ifconfig wlan0 down
airmon-ng check kill
iwconfig wlan0 mode monitor
ifconfig wlan0 up

# Scan
airodump-ng wlan0

# Capture handshake
airodump-ng -c <channel> --bssid <AP_MAC> -w capture wlan0

# Deauth (for handshake capture)
aireplay-ng --deauth 10 -a <AP_MAC> wlan0

# Crack handshake
aircrack-ng -w wordlist.txt capture-01.cap
```

---

## Log Analysis

```bash
# Auth log analysis
./log-analyzer.sh -f /var/log/auth.log

# Check for failed SSH
grep "Failed password" /var/log/auth.log | awk '{print $11}' | sort | uniq -c | sort -rn

# Last logins
last -20

# Currently logged in
w

# Check for rootkits
chkrootkit  # if installed
rkhunter --check  # if installed
```

---

## Android-Specific

```bash
# APK analysis
apktool d app.apk
jadx app.apk -d output/

# Certificate pinning bypass (with Frida)
frida -U -f com.target.app -l bypass.js --no-pause

# ADB over WiFi
adb tcpip 5555
adb connect <phone-ip>:5555

# Termux API
termux-clipboard-get
termux-clipboard-set "text"
termux-notification -t "Title" -c "Content"
termux-toast "Hello"
termux-vibrate -f
termux-battery-status
termux-wifi-connectioninfo
```

---

## Useful Aliases

Add to `~/.bashrc`:
```bash
alias ll='ls -la'
alias ports='netstat -tulanp'
alias myip='curl -s ifconfig.me'
alias localip='ip addr show wlan0 | grep inet | awk "{print \$2}" | cut -d/ -f1'
alias scan='nmap -sT -T4'
alias vscan='nmap -sC -sV -O'
alias serve='python3 -m http.server 8080'
alias urlencode='python3 -c "import urllib.parse; print(urllib.parse.quote(input()))"'
alias urldecode='python3 -c "import urllib.parse; print(urllib.parse.unquote(input()))"'
```
