# Fish completions for QTX security toolkit

complete -c scan -f
complete -c recon -f
complete -c audit -f
complete -c ssl -f
complete -c hashid -f
complete -c logs -f
complete -c vuln -f
complete -c wifi -f
complete -c dirbrute -f
complete -c nikto -f
complete -c hunt -f

complete -c hunt -s o -r -d "Output directory"
complete -c hunt -s s -d "Skip scanner"
complete -c hunt -s r -d "Skip recon"
complete -c hunt -s v -d "Skip vuln-check"
complete -c hunt -s l -d "Skip ssl-check"
complete -c hunt -s t -d "Skip nikto"
complete -c hunt -s q -d "Quiet mode"
complete -c hunt -l help -d "Show help"

complete -c fm -f

complete -c net -s p -r -d "Ping target"
complete -c net -s s -d "Speed test"
complete -c net -s l -d "Latency only"
complete -c net -s a -d "All tests"
complete -c net -s n -r -d "Ping count"
complete -c net -l help -d "Show help"

complete -c scan -l help -d "Show scan help"
complete -c recon -l help -d "Show recon help"
complete -c ssl -l help -d "Show ssl-check help"
complete -c vuln -l help -d "Show vuln-check help"
complete -c wifi -l help -d "Show wifi-recon help"
complete -c dirbrute -l help -d "Show dir-brute help"
complete -c nikto -l help -d "Show nikto-scan help"
