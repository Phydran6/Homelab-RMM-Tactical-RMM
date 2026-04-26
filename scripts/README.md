# Scripts

Shell-Scripts für Update-Management und Systemwartung auf Debian/Ubuntu.

| Script | Beschreibung | Ausführung |
|--------|--------------|------------|
| [update-check.sh](update-check.sh) | Prüft verfügbare Updates und kategorisiert sie nach Priorität (KRITISCH / MITTEL / NIEDRIG) | `update-check.sh` |
| [server-update.sh](server-update.sh) | Installiert unkritische Updates automatisch, zeigt kritische zur manuellen Installation an | `sudo server-update.sh` |
| [Linux - Patch Check](Linux%20-%20Patch%20Check) | Intelligentes Update-System mit interaktivem Timeout-Menü (für Tactical RMM Agent) | via TRMM |
| [Linux - Debain Fesplatte erweitern](Linux%20-%20Debain%20Fesplatte%20erweitern) | Erweitert automatisch die Root-Partition einer Debian VM in Proxmox nach Festplatten-Vergrößerung | via TRMM |

## Update-Kategorisierung

| Priorität | Beispiele | Aktion |
|-----------|-----------|--------|
| **KRITISCH** | Kernel, openssl, sudo, openssh, grub | Manuelle Installation – Reboot oder Risiko |
| **MITTEL** | systemd, apt, dpkg, network | Zeitnahe manuelle Installation empfohlen |
| **NIEDRIG** | Alle übrigen Pakete | Automatische Installation durch `server-update.sh` |
