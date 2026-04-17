#!/bin/bash
# ==============================================================================
# install.sh
# Quick Installation Script für Homelab Infrastructure
# ==============================================================================
# Autor:    Phydran6
# Version:  2026-02-01
# System:   Debian/Ubuntu
# ==============================================================================

set -e  # Exit on error

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktionen
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

print_header() {
    echo ""
    echo "========================================="
    echo "$1"
    echo "========================================="
    echo ""
}

# Header
clear
print_header "Homelab Infrastructure - Installation"

# System Check
print_info "Prüfe System-Voraussetzungen..."

if [ "$EUID" -ne 0 ]; then
    print_error "Bitte als root ausführen (sudo ./install.sh)"
    exit 1
fi

if [ ! -f /etc/debian_version ] && [ ! -f /etc/lsb-release ]; then
    print_error "Dieses Script ist für Debian/Ubuntu optimiert"
    exit 1
fi

print_success "System-Check erfolgreich"

# Installation
print_header "Installiere Update-Scripts"

# Scripts installieren
if [ -f "scripts/update-check.sh" ]; then
    cp scripts/update-check.sh /usr/local/bin/
    chmod +x /usr/local/bin/update-check.sh
    print_success "update-check.sh installiert"
else
    print_error "scripts/update-check.sh nicht gefunden"
    exit 1
fi

if [ -f "scripts/server-update.sh" ]; then
    cp scripts/server-update.sh /usr/local/bin/
    chmod +x /usr/local/bin/server-update.sh
    print_success "server-update.sh installiert"
else
    print_error "scripts/server-update.sh nicht gefunden"
    exit 1
fi

# Optionale Cron-Job Einrichtung
print_header "Cron-Job Einrichtung (Optional)"

read -p "Möchtest du einen automatischen Update-Check einrichten? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    CRON_CMD="0 2 * * * /usr/local/bin/update-check.sh >> /var/log/update-check.log 2>&1"
    
    # Prüfe ob Cron-Job bereits existiert
    if crontab -l 2>/dev/null | grep -q "update-check.sh"; then
        print_info "Cron-Job existiert bereits"
    else
        (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -
        print_success "Cron-Job eingerichtet (täglich um 2 Uhr)"
    fi
fi

# Zusammenfassung
print_header "Installation abgeschlossen"

echo "Installierte Befehle:"
echo "  → update-check.sh     - Update-Prüfung mit Kategorisierung"
echo "  → server-update.sh    - Automatische Installation unkritischer Updates"
echo ""
echo "Verwendung:"
echo "  $ update-check.sh                # Updates prüfen"
echo "  $ sudo server-update.sh          # Updates installieren"
echo ""
echo "Dokumentation:"
echo "  → docs/Homelab-Infrastructure-Dokumentation.md"
echo "  → https://github.com/yourusername/homelab-infrastructure"
echo ""

print_success "Bereit! 🚀"
