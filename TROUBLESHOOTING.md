# Termux Security Toolkit — Troubleshooting

Real problems we hit and how to fix them. Not hypothetical — these all happened.

---

## `/tmp` Directory Broken

**Symptom:** `Permission denied` or `Unable to write to /tmp`

Termux's `/data/local/tmp` is `shell:shell` mode 1771 — your UID can't write to it.

**Fix:**
```bash
mkdir -p ~/tmp
export TMPDIR=$HOME/tmp TMP=$HOME/tmp TEMP=$HOME/tmp TEMPDIR=$HOME/tmp
```

Add to `~/.bashrc` for persistence:
```bash
echo 'export TMPDIR=$HOME/tmp TMP=$HOME/tmp TEMP=$HOME/tmp TEMPDIR=$HOME/tmp' >> ~/.bashrc
```

**This affects:** nikto output, python temp files, any tool that writes to `/tmp`.

---

## Nikto Runtime Fixes

Nikto on Termux needs 3 fixes before it works.

### 1. IO::Socket::SSL missing
```
Can't locate IO/Socket/SSL.pm
```
**Fix:**
```bash
cpan -T IO::Socket::SSL
```

### 2. nikto.conf missing
```
Error: nikto.conf not found
```
**Fix:**
```bash
cp /data/data/com.termux/files/usr/share/nikto/program/nikto.conf.default \
   /data/data/com.termux/files/usr/share/nikto/program/nikto.conf
sed -i 's|TEMPLATES=/usr/share/nikto/program/templates|TEMPLATES=/data/data/com.termux/files/usr/share/nikto/program/templates|' \
   /data/data/com.termux/files/usr/share/nikto/program/nikto.conf
```

### 3. /tmp write permission
```
Unable to open '/tmp/nikto_scan.txt' for write
```
**Fix:** Output to home directory instead:
```bash
mkdir -p ~/nikto-output
nikto -h <target> -output ~/nikto-output/scan.txt
```

---

## Node.js / npm / npx Issues

### Shebang broken (`/usr/bin/env: bad interpreter`)
Termux's `/usr/bin/env` path doesn't match npm's expectations.

**Fix:** Run via node directly:
```bash
# Instead of npx something
node ./node_modules/something/bin/script.js

# Instead of npm global bin
node ~/.npm-global/lib/node_modules/package/bin/script.js
```

### Turbopack unsupported on ARM
```
Turbopack is not supported on this platform (android/arm64)
```
**Fix:** Use webpack:
```bash
node ./node_modules/next/dist/bin/next build --webpack
```

### npm install timeout
```
npm ERR! code FETCH_ERROR
```
**Fix:**
```bash
npm install --fetch-timeout=120000
```

### npx can't find package
```bash
# Instead of: npx package-name
npm install -g package-name
package-name  # or: node $(npm root -g)/package-name/bin/index.js
```

---

## Python Issues

### pydantic-core won't compile
Some packages (aiogram, etc.) depend on pydantic-core which needs a C compiler and specific glibc.

**Fix:** Avoid packages with pydantic-core. Use stdlib or lighter alternatives.

### psutil fails
```
PermissionError: [Errno 13] Permission denied: '/proc/stat'
```
Some Android kernels restrict `/proc` access.

**Fix:** Use `os` stdlib for CPU/memory, or catch the error:
```python
try:
    import psutil
except:
    import os
    # fallback to /proc parsing or os module
```

### pip install timeout
```
ReadTimeoutError
```
**Fix:**
```bash
pip install --timeout=120 package-name
```

---

## No `sudo`

Termux doesn't have sudo. All installs are user-level.

**Workarounds:**
- `pkg install` for system packages (runs as Termux user)
- `pip install --user` or just `pip install` (installs to `~/.local/lib`)
- `npm install -g` (installs to `~/.npm-global/`)
- For root access: `tsu` (installs `tsu` package, uses `su` binary)

---

## nmap on Termux

nmap works but with limitations:
- No SYN scan without root (`-sS` requires `tsu`)
- OS detection (`-O`) requires root
- Script engine (`--script`) works

**Fix for root features:**
```bash
pkg install tsu
tsu  # get root shell
nmap -sS -O <target>
```

---

## SSH Issues

### Key permission errors
```
Permissions 0644 for 'id_rsa' are too open
```
**Fix:**
```bash
chmod 600 ~/.ssh/id_rsa
chmod 700 ~/.ssh
```

### SSH host key changed
```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```
**Fix:**
```bash
ssh-keygen -R <hostname>
```

### Agent forwarding
```bash
# Start agent
eval $(ssh-agent -s)
ssh-add ~/.ssh/id_rsa

# Verify
ssh-add -l
```

---

## curl / SSL Issues

### SSL certificate verify failed
```
curl: (60) SSL certificate problem: unable to get local issuer certificate
```
**Fix (testing only — never in production):**
```bash
curl -k <url>  # skip verification
```

**Proper fix:**
```bash
pkg install ca-certificates
```

---

## Git Issues

### Detached HEAD
```bash
# You're in detached HEAD state
git checkout main  # or whatever branch
```

### Push rejected (diverged)
```bash
# Option 1: force push (destructive)
git push --force-with-lease

# Option 2: reset to remote
git fetch origin
git reset --hard origin/main
```

### Large file in history
```bash
# Remove from all history
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch path/to/large/file' \
  --prune-empty --tag-name-filter cat -- --all
```

---

## Composio / Remote Sandbox

### Can't access local files from remote workbench
Composio remote sandbox has NO access to local Termux filesystem.

**Workarounds:**
```bash
# Base64 encode (may truncate for large files)
base64 -w0 local-file.txt

# Upload to a public URL first
# Then fetch from remote sandbox
```

### API key auth failures
Composio session IDs change. Always check active session:
```
COMPOSIO_SEARCH_TOOLS → returns session_id
```

---

## Termux Package Issues

### Package not found
```bash
pkg update && pkg upgrade
pkg install <package>
```

### Broken package
```bash
pkg install --force-reinstall <package>
```

### Storage full
```bash
# Check what's eating space
du -sh ~/.npm-global/* | sort -rh | head -5
du -sh ~/.local/lib/* | sort -rh | head -5
du -sh ~/tmp/* | sort -rh | head -5

# Clean caches
npm cache clean --force
pip cache purge
rm -rf ~/tmp/*
```

---

## Quick Reference

| Problem | Fix |
|---------|-----|
| `/tmp` write fail | `export TMPDIR=$HOME/tmp` |
| `/usr/bin/env` bad interpreter | Use `node ./node_modules/.../script.js` |
| Turbopack unsupported | Add `--webpack` to next build |
| nikto Can't locate SSL | `cpan -T IO::Socket::SSL` |
| nikto.conf missing | `cp nikto.conf.default nikto.conf` |
| No sudo | `pkg install tsu && tsu` |
| pip timeout | `pip install --timeout=120` |
| npm timeout | `npm install --fetch-timeout=120000` |
| SSH key open | `chmod 600 ~/.ssh/id_rsa` |
| SSL verify fail | `pkg install ca-certificates` |
| git diverged | `git fetch && git reset --hard origin/main` |
