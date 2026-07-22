# Fish completions for MorphShell security toolkit commands

# tk-scanner
complete -c tk-scanner -s p -x -d "Port range"
complete -c tk-scanner -s s -d "Stealth scan"
complete -c tk-scanner -s v -d "Verbose output"
complete -c tk-scanner -s o -x -d "Output file"
complete -c tk-scanner -s T -r -d "Timeout"
complete -c tk-scanner -s A -d "Aggressive scan"
complete -c tk-scanner -s h -d "Show help"

# tk-recon
complete -c tk-recon -s o -x -d "Output file"
complete -c tk-recon -s q -d "Quiet mode"
complete -c tk-recon -s d -x -d "Depth level"
complete -c tk-recon -s h -d "Show help"

# tk-audit
complete -c tk-audit -s f -x -d "File to audit"
complete -c tk-audit -s g -d "Git analysis"
complete -c tk-audit -s w -d "Wordlist mode"
complete -c tk-audit -s m -x -d "Module"
complete -c tk-audit -s h -d "Show help"

# tk-ssl-check
complete -c tk-ssl-check -s p -x -d "Port"
complete -c tk-ssl-check -s c -x -d "Certificate file"
complete -c tk-ssl-check -s t -x -d "Timeout"
complete -c tk-ssl-check -s j -d "JSON output"
complete -c tk-ssl-check -s o -x -d "Output file"
complete -c tk-ssl-check -s h -d "Show help"

# tk-hash-id
complete -c tk-hash-id -s f -x -d "Hash file"
complete -c tk-hash-id -s c -x -d "Hash to check"
complete -c tk-hash-id -s d -d "Dictionary mode"
complete -c tk-hash-id -s w -x -d "Wordlist"
complete -c tk-hash-id -s h -d "Show help"

# tk-log-analyzer
complete -c tk-log-analyzer -s f -x -d "Log file"
complete -c tk-log-analyzer -s a -d "Alert mode"
complete -c tk-log-analyzer -s t -x -d "Time range"
complete -c tk-log-analyzer -s b -x -d "Base threshold"
complete -c tk-log-analyzer -s j -d "JSON output"
complete -c tk-log-analyzer -s h -d "Show help"

# tk-vuln-check
complete -c tk-vuln-check -s s -x -d "Severity filter"
complete -c tk-vuln-check -s a -d "All targets"
complete -c tk-vuln-check -s o -x -d "Output file"
complete -c tk-vuln-check -s h -d "Show help"

# tk-wifi-recon
complete -c tk-wifi-recon -s i -x -d "Interface"
complete -c tk-wifi-recon -s s -x -d "SSID filter"
complete -c tk-wifi-recon -s m -d "Monitor mode"
complete -c tk-wifi-recon -s c -x -d "Channel"
complete -c tk-wifi-recon -s h -d "Show help"

# tk-dir-brute
complete -c tk-dir-brute -s w -x -d "Wordlist"
complete -c tk-dir-brute -s x -x -d "Extensions"
complete -c tk-dir-brute -s s -x -d "Status codes"
complete -c tk-dir-brute -s o -x -d "Output file"
complete -c tk-dir-brute -s h -d "Show help"

# tk-nikto-scan
complete -c tk-nikto-scan -s p -x -d "Port"
complete -c tk-nikto-scan -s C -x -d "Checklist"
complete -c tk-nikto-scan -s o -x -d "Output file"
complete -c tk-nikto-scan -s f -x -d "Format"
complete -c tk-nikto-scan -s h -d "Show help"

# Alias completions
complete -c scan -w tk-scanner
complete -c recon -w tk-recon
complete -c audit -w tk-audit
complete -c ssl -w tk-ssl-check
complete -c hashid -w tk-hash-id
complete -c logs -w tk-log-analyzer
complete -c vuln -w tk-vuln-check
complete -c wifi -w tk-wifi-recon
complete -c dirbrute -w tk-dir-brute
complete -c nikto -w tk-nikto-scan
