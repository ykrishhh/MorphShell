# MorphShell ✨

A sleek Termux theme with a smart prompt, syntax highlighting, a dynamic animated banner, and a built-in security toolkit.

## Features

- Animated ASCII banner every session
- Smart prompt with dynamic name support
- Syntax highlighting for commands
- Fish shell with eza, bat, and starship
- **7 security tools** built-in (scanner, recon, audit, SSL checker, hash ID, log analyzer, vuln scanner)

## Installation

> Available for Termux users
```
apt install morphshell -y
```

After installation:

1. Launch Termux to see the animated MorphShell banner
2. The shell will automatically switch to fish
3. Customize your prompt name during setup

## Security Toolkit

Built-in tools — no separate install needed.

| Command | Shortcut | What it does |
|---------|----------|--------------|
| `tk-scanner` | `scan` | Network port scanner (nmap wrapper) |
| `tk-recon` | `recon` | OSINT recon — DNS, headers, subdomains |
| `tk-audit` | `audit` | Password strength auditor |
| `tk-ssl-check` | `ssl` | SSL/TLS certificate inspector |
| `tk-hash-id` | `hashid` | Hash identification & cracking |
| `tk-log-analyzer` | `logs` | Auth log brute force detector |
| `tk-vuln-check` | `vuln` | Web vulnerability scanner |

### Quick examples

```bash
scan 192.168.1.1 -T           # quick port scan
recon example.com -d          # deep recon
ssl google.com -c -t          # check SSL + TLS versions
vuln example.com              # find web vulnerabilities
hashid 5f4dcc3b5aa765d61d8327deb882cf99
audit                         # interactive password checker
```

### Termux-specific fixes included

The toolkit handles common Termux issues automatically:
- `/tmp` directory permissions fixed
- Nikto SSL support installed
- Nikto config generated from default
- PATH configured for `~/.local/bin`

See `tools/` directory for the full toolkit source.

## Project Structure

```
MorphShell/
├── assets/
│   ├── config.fish          # Fish shell config + aliases
│   ├── colors.properties    # Termux color scheme
│   ├── font.ttf             # Custom font
│   ├── motd                 # Animated banner
│   └── starship.toml        # Starship prompt config
├── tools/
│   ├── scanner.sh           # Network port scanner
│   ├── recon.sh             # OSINT reconnaissance
│   ├── audit.sh             # Password auditor
│   ├── ssl-check.sh         # SSL/TLS checker
│   ├── hash-id.sh           # Hash identifier
│   ├── log-analyzer.sh      # Auth log analyzer
│   ├── vuln-check.sh        # Web vuln scanner
│   ├── setup.sh             # Environment setup
│   └── lib/
│       ├── colors.sh        # Shared output functions
│       └── utils.sh         # Shared utilities
├── install.sh               # MorphShell + toolkit installer
└── LICENSE                  # MIT License
```

## License

MIT / Open-source
