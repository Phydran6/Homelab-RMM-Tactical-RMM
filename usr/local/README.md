# Scripts (`/usr/local`)

Die Verzeichnisstruktur in diesem Repo entspricht den Zielpfaden auf dem Server – `install.sh` kopiert jede Datei 1:1 an dieselbe Stelle (`usr/local/sbin/trmmctl` → `/usr/local/sbin/trmmctl`).

| Script | Zielpfad | Beschreibung | Ausführung |
|--------|----------|--------------|------------|
| [trmmctl](sbin/trmmctl) | `/usr/local/sbin/` | Verwaltung der TRMM-Installation unter `/opt/trmm`: Status, Update, Zertifikat, Backup/Restore, DB-Migration, Systemcheck | `sudo trmmctl help` |
| [update-check](bin/update-check) | `/usr/local/bin/` | Prüft verfügbare Updates und kategorisiert sie (KRITISCH / MITTEL / NIEDRIG) | `update-check` |
| [server-update](sbin/server-update) | `/usr/local/sbin/` | Installiert unkritische Updates automatisch, zeigt kritische zur manuellen Installation an | `sudo server-update` |
| [apt-smart-update](sbin/apt-smart-update) | `/usr/local/sbin/` | Update mit interaktivem Timeout-Menü (früher „Linux - Patch Check“, auch als TRMM-Script) | `sudo apt-smart-update` / via TRMM |
| [pve-disk-resize](sbin/pve-disk-resize) | `/usr/local/sbin/` | Erweitert die Root-Partition einer Debian-VM in Proxmox nach Festplatten-Vergrößerung (früher „Linux - Debain Fesplatte erweitern“) | `sudo pve-disk-resize` / via TRMM |

Die alten Aufrufe `update-check.sh` und `server-update.sh` funktionieren weiter (Symlinks).

## Als TRMM-Script verwenden

`apt-smart-update` und `pve-disk-resize` laufen ohne Eingabe vollautomatisch mit den Defaults. Inhalt der Datei in TRMM unter **Settings → Script Manager → New Script** (Shell: Bash, Plattform: Linux) einfügen.

## Update-Kategorisierung

| Priorität | Beispiele | Aktion |
|-----------|-----------|--------|
| **KRITISCH** | Kernel, openssl, sudo, openssh, grub | Manuelle Installation – Reboot oder Risiko |
| **MITTEL** | systemd, apt, dpkg, network, docker-ce, containerd | Zeitnahe manuelle Installation empfohlen |
| **NIEDRIG** | Alle übrigen Pakete | Automatische Installation durch `server-update` |

Docker-Engine-Pakete werden nicht automatisch aktualisiert, da ein Update alle Container (also TRMM selbst) neu startet.
