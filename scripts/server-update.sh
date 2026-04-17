#!/bin/bash
# ==============================================================================
# server-update.sh
# Installiert unkritische Updates automatisch, kritische manuell
# ==============================================================================
# Autor:    Phydran6
# Version:  2026-01-05
# System:   Debian/Ubuntu
# ==============================================================================
# Logik:
#   - NIEDRIG Pakete werden automatisch installiert
#   - KRITISCH/MITTEL Pakete werden angezeigt mit Installationsbefehl
# ==============================================================================

# kritische pakete pattern (werden NICHT automatisch installiert)
KRITISCH_PATTERN="^(linux-image|linux-headers|openssl|libssl|libcrypto|grub|initramfs|efi|sudo|openssh|libpam-|systemd|libudev|libsystemd|libc6|libgcc|bash|coreutils|util-linux)"

# paketlisten aktualisieren
echo "=> paketlisten aktualisieren..."
apt-get update -qq 2>/dev/null || exit 1

# updates holen
UPDATES=$(apt list --upgradable 2>/dev/null | grep "/" | sort)
[ -z "$UPDATES" ] && { echo "OK - keine updates"; exit 0; }

# kategorisieren
declare -a AUTO=() MANUELL=()
while IFS= read -r line; do
    [ -z "$line" ] && continue
    pkg=$(echo "$line" | cut -d'/' -f1)
    if echo "$pkg" | grep -qiE "$KRITISCH_PATTERN"; then
        MANUELL+=("$pkg")
    else
        AUTO+=("$pkg")
    fi
done <<< "$UPDATES"

# automatisch installieren
if [ ${#AUTO[@]} -gt 0 ]; then
    echo "=> installiere ${#AUTO[@]} unkritische(s) paket(e)..."
    for pkg in "${AUTO[@]}"; do
        echo "   $pkg"
    done
    apt-get install -y "${AUTO[@]}" 2>&1 | grep -E "^(Inst|Conf|Setting up)" || true
fi

# kritische anzeigen
if [ ${#MANUELL[@]} -gt 0 ]; then
    echo ""
    echo "========================================"
    echo "KRITISCHE UPDATES - MANUELLE INSTALLATION"
    echo "========================================"
    echo ""
    echo "Folgende ${#MANUELL[@]} Paket(e) wurden NICHT installiert"
    echo "(Kernel/Boot/Systemd/Core - Reboot oder Risiko):"
    echo ""
    for pkg in "${MANUELL[@]}"; do
        echo "  $pkg"
        echo "    -> sudo apt install $pkg"
        echo ""
    done
    echo "Alle kritischen auf einmal:"
    echo "  -> sudo apt install ${MANUELL[*]}"
fi

# cache aufraeumen
echo ""
echo "=> cache aufraeumen..."
apt-get autoclean -qq 2>/dev/null

# zusammenfassung
echo ""
echo "========================================"
echo "ZUSAMMENFASSUNG"
echo "========================================"
echo "Installiert:     ${#AUTO[@]} paket(e)"
echo "Uebersprungen:   ${#MANUELL[@]} paket(e) (kritisch)"
