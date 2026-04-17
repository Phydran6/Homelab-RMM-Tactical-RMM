#!/bin/bash
# ==============================================================================
# update-check.sh
# Prueft auf Updates und kategorisiert nach Prioritaet
# ==============================================================================
# Autor:    Phydran6
# Version:  2026-01-05
# System:   Debian/Ubuntu
# ==============================================================================
# Kategorien:
#   KRITISCH  Security, Kernel, SSL, Auth
#   MITTEL    Systemd, Netzwerk, Paketmanager
#   NIEDRIG   Rest
# ==============================================================================
# Ausgabe-Beispiele:
#   OK - keine updates
#   3 UPDATE(S)
#   ----------------
#   KRITISCH: openssl libssl3
#   NIEDRIG: vim
# ==============================================================================

# paketlisten holen
if ! apt-get update -qq 2>/dev/null; then
    echo "FEHLER: apt update fehlgeschlagen"
    exit 0
fi

# updates abfragen
UPDATES=$(apt list --upgradable 2>/dev/null | grep "/" | sort)

if [ -z "$UPDATES" ]; then
    echo "OK - keine updates"
    exit 0
fi

# kategorien
declare -a KRIT=() MITT=() NIED=()

# einsortieren
while IFS= read -r line; do
    [ -z "$line" ] && continue
    pkg=$(echo "$line" | cut -d'/' -f1)
    
    # kritisch: security, kernel, ssl, auth
    if echo "$line" | grep -qE "(security|/stable-security)"; then
        KRIT+=("$pkg")
    elif echo "$pkg" | grep -qiE "^(linux-image|linux-headers|openssl|libssl|grub|sudo|openssh|libpam-)"; then
        KRIT+=("$pkg")
    # mittel: systemd, netzwerk, paketmanager
    elif echo "$pkg" | grep -qiE "^(systemd|libnss|libudev|libsystemd|base-files|apt|dpkg|network|udev|dbus)"; then
        MITT+=("$pkg")
    # niedrig: rest
    else
        NIED+=("$pkg")
    fi
done <<< "$UPDATES"

# ausgabe
TOTAL=$((${#KRIT[@]} + ${#MITT[@]} + ${#NIED[@]}))
echo "$TOTAL UPDATE(S)"
echo "----------------"
[ ${#KRIT[@]} -gt 0 ] && echo "KRITISCH: ${KRIT[*]}"
[ ${#MITT[@]} -gt 0 ] && echo "MITTEL: ${MITT[*]}"
[ ${#NIED[@]} -gt 0 ] && echo "NIEDRIG: ${NIED[*]}"
