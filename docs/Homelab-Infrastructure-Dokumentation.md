# HOMELAB INFRASTRUCTURE DOKUMENTATION

**Phydran6**  
**Stand: Oktober 2026**

---

## Inhaltsverzeichnis

1. [Übersicht](#1-übersicht)
2. [Installation (Online-Installer)](#2-installation-online-installer)
3. [Tactical RMM Docker Deployment](#3-tactical-rmm-docker-deployment)
4. [SSL-Zertifikate mit Certbot](#4-ssl-zertifikate-mit-certbot)
5. [Update-Management Scripts](#5-update-management-scripts)
6. [Pi-hole Konfiguration](#6-pi-hole-konfiguration)
7. [Troubleshooting](#7-troubleshooting)
8. [Quick Reference](#8-quick-reference)

---

## 1. Übersicht

Diese Dokumentation beschreibt die Einrichtung und Wartung der Homelab-Infrastruktur mit Fokus auf System-Automatisierung und Monitoring.

### 1.1 Kernkomponenten

- **Tactical RMM (TRMM)** - System Monitoring und Remote Management
- **Docker** - Container-Plattform für alle Services
- **Nginx Proxy Manager** - SSL-Terminierung und Reverse Proxy
- **Pi-hole** - DNS-Filtering
- **Certbot** - Let's Encrypt Wildcard-Zertifikate
- **Custom Update Scripts** - Automatisierte Paketverwaltung
- **trmmctl** - Verwaltung von Update, Zertifikat, Backup und Migration

### 1.2 Domain-Struktur

**Hauptdomain:** phytech.de

| Subdomain | Zweck |
|-----------|-------|
| rmm.phytech.de | Tactical RMM Frontend |
| api.phytech.de | Tactical RMM API |
| mesh.phytech.de | MeshCentral Remote Access |

### 1.3 Infrastruktur

- **Virtualisierung:** Proxmox (CPU-Typ `host` oder `x86-64-v3`, siehe [7.7](#77-mongodb-startet-nicht-illegal-instruction))
- **Betriebssystem:** Debian 13 (Trixie) / Debian 12 (Bookworm)
- **DNS-Server:** Pi-hole (192.168.179.30)

### 1.4 Verzeichnisse auf dem Server

| Pfad | Inhalt |
|------|--------|
| `/opt/trmm/` | `docker-compose.yml`, `.env` (Rechte 600), `.env.example` |
| `/usr/local/sbin/trmmctl` | Verwaltungstool |
| `/usr/local/sbin/server-update`, `apt-smart-update`, `pve-disk-resize` | Root-Scripts |
| `/usr/local/bin/update-check` | Update-Prüfung |
| `/etc/default/trmm` | Einstellungen für trmmctl (Backup-Ziel, Cert-Domain) |
| `/etc/systemd/system/trmm-backup.timer` | tägliches Backup |
| `/etc/systemd/system/update-check.timer` | täglicher Update-Check |
| `/var/backups/trmm/` | Backups und Migrations-Dumps |
| `/etc/letsencrypt/live/<domain>/` | Zertifikate |

---

## 2. Installation (Online-Installer)

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh | sudo bash
```

Ohne Rückfragen:

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh \
  | sudo bash -s -- --domain phytech.de --admin admin --yes
```

Der Installer:

1. prüft System, RAM, Systemzeit (aktiviert NTP) und DNS (Pi-hole-Blockaden) und bricht ohne AVX-fähige CPU ab, bevor etwas verändert wird
2. installiert Docker Engine + Compose v2 aus dem offiziellen Docker-Repository
3. legt alle Dateien in die Standardpfade (siehe [1.4](#14-verzeichnisse-auf-dem-server))
4. übernimmt eine bestehende Installation aus `~/trmm` bzw. `~/tactical-rmm`
5. erzeugt `/opt/trmm/.env` mit zufälligen Passwörtern und pinnt das aktuelle TRMM-Release
6. übernimmt ein vorhandenes Let's-Encrypt-Zertifikat
7. richtet die systemd-Timer ein und startet den Stack

> **Erneut ausführen = Update** der Scripts und des Compose-Files. Die `.env` wird nie überschrieben, nur um fehlende Schlüssel ergänzt. Alternativ: `sudo trmmctl self-update`.

Nur die Update-Scripts (z.B. auf anderen Servern):

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh | sudo bash -s -- --tools-only
```

### 2.1 Docker manuell (falls ohne Installer)

> **⚠️ WICHTIG:** Nicht das alte Debian-Paket `docker-compose` (v1) verwenden.

```bash
# Offizielles Docker-Repository
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
cat <<EOF | sudo tee /etc/apt/sources.list.d/docker.sources
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
sudo apt update
sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

docker compose version
```

---

## 3. Tactical RMM Docker Deployment

**Offizielle Dokumentation:** https://docs.tacticalrmm.com/install_docker/

### 3.1 Voraussetzungen

- 3 DNS A-Records: `rmm`, `api`, `mesh` → Server-IP (bzw. Reverse Proxy)
- Wildcard SSL-Zertifikat (*.phytech.de)
- Port 443 in Firewall geöffnet

### 3.2 Images

Das Compose-File unter `/opt/trmm` basiert auf dem Upstream-File von amidaware, nutzt aber aktuelle Datenbank-Images:

| Dienst | Upstream | Hier | Variable in `.env` |
|--------|----------|------|--------------------|
| PostgreSQL | `postgres:13-alpine` (EOL) | `postgres:18-alpine` | `POSTGRES_VERSION` |
| Redis | `redis:6.0-alpine` (EOL) | `redis:8-alpine` | `REDIS_VERSION` |
| MongoDB | `mongo:4.4` (EOL) | `mongo:8.0` | `MONGO_VERSION` |
| TRMM | `VERSION=latest` | gepinnt, z.B. `1.5.2` | `VERSION` |

Zusätzlich: Healthchecks mit `depends_on`-Conditions, Log-Rotation (3×10 MB je Container), begrenzter MongoDB-Cache (`MONGO_CACHE_GB=0.25`), Redis/MongoDB mit dem Privilege-Drop der offiziellen Images.

Die DB-Volumes tragen die Major-Version im Namen (`trmm_postgres18_data`, `trmm_mongo8.0_data`). Dadurch startet ein Versionswechsel nie auf einem leeren Volume, während die Daten noch im alten liegen – `trmmctl` verweigert dann den Start und verweist auf `trmmctl migrate-db`.

### 3.3 Zertifikat mit Certbot erstellen

Siehe [Abschnitt 4](#4-ssl-zertifikate-mit-certbot) bzw. [wartung/01](../wartung/01-ssl-zertifikat-erneuern.md). Danach:

```bash
sudo trmmctl cert phytech.de
```

### 3.4 Konfiguration

```bash
sudo nano /opt/trmm/.env
```

Wichtige Werte (vom Installer gesetzt):
```
APP_HOST=rmm.phytech.de
API_HOST=api.phytech.de
MESH_HOST=mesh.phytech.de
TRMM_USER=admin
TRMM_PASS=<zufällig>
VERSION=1.5.2
```

Nach Änderungen: `sudo trmmctl restart`

### 3.5 Container starten

```bash
sudo trmmctl up

# Logs beobachten (Init dauert 5-10 Minuten!)
sudo trmmctl logs init
```

> **⚠️ WICHTIG:** Die Initialisierung der Container dauert **5-10 Minuten**. Geduld!

### 3.6 Benutzer

Der Admin aus `TRMM_USER`/`TRMM_PASS` wird beim Init automatisch angelegt. Weitere Admins:

```bash
sudo trmmctl createsuperuser
```

### 3.7 NPM (Nginx Proxy Manager) Konfiguration

Falls NPM als Reverse Proxy verwendet wird, alle 3 Proxy Hosts auf Port 80 der TRMM-Box zeigen lassen:

| Domain | Forward Port | WebSocket |
|--------|-------------|-----------|
| rmm.phytech.de | 80 | ON |
| api.phytech.de | 80 | OFF |
| mesh.phytech.de | 80 | ON |

SSL: Wildcard-Zertifikat `*.phytech.de`, Force SSL ON

### 3.8 Backup & Restore

```bash
sudo trmmctl backup                                   # manuell
systemctl list-timers trmm-backup.timer               # täglich 03:15
sudo trmmctl restore /var/backups/trmm/trmm-<datum>.tar
```

Ein Backup enthält PostgreSQL-Dump, MeshCentral-Datenbank, MeshCentral-Daten, TRMM-Zertifikate/private Dateien, `.env` und Compose-File. Anzahl: `BACKUP_KEEP` in `/etc/default/trmm`.

### 3.9 Migration einer alten Installation

Der Installer erkennt einen laufenden Stack (bzw. `~/trmm`, `~/tactical-rmm`), kopiert die `.env` nach `/opt/trmm`, behält den Compose-Projektnamen (damit `tactical_data`/`mesh_data` weiter genutzt werden), stoppt den alten Stack und ruft `trmmctl migrate-db` auf:

1. alter PostgreSQL-13-Container auf dem alten Volume → `pg_dump`
2. neuer PostgreSQL-18-Container auf neuem Volume → Import
3. dasselbe für MongoDB 4.4 → 8.0 (`mongodump`/`mongorestore`)

Die alten Volumes bleiben unverändert als Rollback erhalten, die Dumps liegen unter `/var/backups/trmm/migrate-*`. Wenn alles läuft:

```bash
docker volume ls | grep trmm
docker volume rm trmm_postgres_data trmm_mongo_data
```

---

## 4. SSL-Zertifikate mit Certbot

### 4.1 Zertifikat-Speicherort

```
/etc/letsencrypt/live/phytech.de/
├── fullchain.pem   # Öffentlicher Schlüssel + Zertifikatskette
├── privkey.pem     # Privater Schlüssel
├── cert.pem        # Nur das Zertifikat
└── chain.pem       # Nur die Kette
```

### 4.2 Wildcard-Zertifikat anfordern

```bash
sudo apt install certbot

sudo certbot certonly --manual -d "*.phytech.de" \
  --agree-tos --preferred-challenges dns
```

Bei der Aufforderung: TXT-Record `_acme-challenge.phytech.de` im DNS-Manager eintragen und prüfen:

```bash
dig -t txt _acme-challenge.phytech.de @8.8.8.8
```

> **Erst nach erfolgreicher Verifikation Enter drücken!**

### 4.3 In TRMM übernehmen

```bash
sudo trmmctl cert                         # Domain aus /etc/default/trmm
sudo trmmctl cert --export /root/npm      # zusätzlich npm-*.pem für NPM
```

Ausführlich inkl. NPM: [wartung/01-ssl-zertifikat-erneuern.md](../wartung/01-ssl-zertifikat-erneuern.md)

---

## 5. Update-Management Scripts

Komplementäre Scripts für sichere System-Updates mit automatischer Kategorisierung.

| Script | Pfad | Zweck |
|--------|------|-------|
| `update-check` | `/usr/local/bin/` | Nur prüfen und kategorisieren |
| `server-update` | `/usr/local/sbin/` | Unkritische Updates automatisch, kritische anzeigen |
| `apt-smart-update` | `/usr/local/sbin/` | Wie server-update, mit Timeout-Menü (auch als TRMM-Script) |
| `pve-disk-resize` | `/usr/local/sbin/` | Root-Partition nach Disk-Vergrößerung in Proxmox erweitern |

Quelltext: [usr/local/](../usr/local/)

### 5.1 Kategorisierung

| Priorität | Beschreibung | Aktion |
|-----------|--------------|--------|
| **KRITISCH** (rot) | Security, Kernel, SSL, Auth | Manuelle Installation |
| **MITTEL** (gelb) | Systemd, Netzwerk, Core, Docker-Engine | Zeitnah installieren |
| **NIEDRIG** (grün) | Alles andere | Automatisch installierbar |

**KRITISCH - Pakete:**
- `linux-image-*`, `linux-headers-*`
- `openssl`, `libssl*`, `libcrypto*`
- `grub*`, `initramfs*`, `efi*`
- `sudo`, `openssh*`, `libpam-*`
- Alle Pakete aus security-repos

**MITTEL - Pakete:**
- `systemd*`, `libudev*`, `libsystemd*`
- `base-files`, `apt`, `dpkg`
- `network*`, `dbus*`
- `docker*`, `containerd*`, `runc` – ein Update startet alle TRMM-Container neu

**NIEDRIG - Pakete:**
- Normale Anwendungen
- Unkritische Libraries

### 5.2 Verhalten

- Installiert wird mit `apt-get install --only-upgrade` ohne Rückfragen (`DEBIAN_FRONTEND=noninteractive`, geänderte Config-Dateien bleiben erhalten).
- Die Auto-Markierung von Abhängigkeiten bleibt erhalten, damit `apt autoremove` weiterhin aufräumt.

### 5.3 Beispiel-Ausgabe update-check

```
24 UPDATE(S)
----------------
KRITISCH: linux-image-amd64 openssl libssl3
MITTEL: systemd base-files
NIEDRIG: vim curl nginx
```

### 5.4 Beispiel-Ausgabe server-update

```
=> paketlisten aktualisieren...
=> installiere 12 unkritische(s) paket(e)...

========================================
KRITISCHE UPDATES - MANUELLE INSTALLATION
========================================
  linux-image-6.12.48-amd64
    -> sudo apt install --only-upgrade linux-image-6.12.48-amd64
  systemd
    -> sudo apt install --only-upgrade systemd

Alle kritischen auf einmal:
  -> sudo apt install --only-upgrade linux-image-6.12.48-amd64 systemd

========================================
ZUSAMMENFASSUNG
========================================
Installiert:     12 paket(e)
Uebersprungen:   2 paket(e) (kritisch)
```

### 5.5 Automatisch ausführen

```bash
sudo systemctl enable --now update-check.timer   # täglich 02:00
journalctl -u update-check                       # Ausgabe
```

---

## 6. Pi-hole Konfiguration

Pi-hole kann Docker/GitHub/Debian Mirrors blockieren. Whitelist-Einträge nötig. `sudo trmmctl doctor` prüft die wichtigsten Domains.

### 6.1 Wichtige Whitelist-Domains

```
# Docker
docker.com
docker.io
download.docker.com
registry.hub.docker.com
hub.docker.com
auth.docker.io
registry-1.docker.io
production.cloudflare.docker.com

# GitHub
github.com
api.github.com
githubusercontent.com
raw.githubusercontent.com
ghcr.io

# Debian/Ubuntu Mirrors
deb.debian.org
security.debian.org
cdn-fastly.deb.debian.org
ftp.de.debian.org
mirror.netcologne.de

# Let's Encrypt
letsencrypt.org
acme-v02.api.letsencrypt.org

# NPM (falls benötigt)
registry.npmjs.org
```

### 6.2 Empfohlene Blocklists

```
# Hagezi Light (gut balanciert)
https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/light.txt

# Plus anudeepND Whitelist
https://raw.githubusercontent.com/anudeepND/whitelist/master/domains/whitelist.txt
```

### 6.3 Symptom: APT-Mirrors werden geblockt

Wenn `apt update` fehlschlägt und Domains auf `0.0.0.0` / `127.0.0.1` aufgelöst werden → Pi-hole blockiert!

**Lösung:** Domains in Pi-hole Whitelist eintragen.

---

## 7. Troubleshooting

Erster Schritt immer: `sudo trmmctl doctor` und `sudo trmmctl status`.

### 7.1 VM-Zeit falsch - APT schlägt fehl

**Symptom:** `Release-Datei ist noch nicht gültig`

```bash
# Systemzeit synchronisieren
sudo timedatectl set-ntp true
sleep 5
timedatectl

# APT mit deaktivierter Zeitprüfung (nur als Notlösung)
sudo apt-get update -o Acquire::Check-Valid-Until=false
```

> **⚠️ WICHTIG:** Systemzeit MUSS korrekt sein bevor Pakete installiert werden!

### 7.2 Docker Netzwerk-Konflikte

```bash
sudo trmmctl down
docker network prune -f
sudo trmmctl up
```

### 7.3 TRMM Init-Container hängt

Die Initialisierung dauert 5-10 Minuten. Geduld!

```bash
sudo trmmctl logs init
sudo trmmctl ps
```

> ⚠️ Nicht mehr `docker compose down -v` verwenden – das löscht alle Volumes inklusive Datenbank. Stattdessen Logs prüfen, notfalls `trmmctl restore`.

### 7.4 "Volume ... fehlt, es gibt aber ..."

`POSTGRES_VERSION` oder `MONGO_VERSION` in der `.env` wurde geändert (oder eine alte Installation übernommen). Daten übernehmen:

```bash
sudo trmmctl migrate-db
```

### 7.5 ANSI-Farbcodes im Terminal

Scripts erkennen automatisch ob Terminal Farben unterstützt (wichtig für die TRMM-Ausgabe):

```bash
if [ -t 1 ]; then
    RED='\033[0;31m' GREEN='\033[0;32m' NC='\033[0m'
else
    RED='' GREEN='' NC=''
fi
```

### 7.6 .env Datei hat falsche Berechtigungen

```bash
sudo chown root:root /opt/trmm/.env
sudo chmod 600 /opt/trmm/.env
```

### 7.7 MongoDB startet nicht ("Illegal instruction")

MongoDB ab 5.0 braucht eine CPU mit AVX. Der Proxmox-Default-CPU-Typ (`x86-64-v2-AES`/`kvm64`) reicht nicht.

Der Installer prüft das vorab und bricht ohne AVX ab, ohne etwas zu verändern.

- **Lösung:** VM herunterfahren → Hardware → Prozessor → Typ `host` oder `x86-64-v3` → VM starten → Installer erneut ausführen.
- **Prüfen:** `grep -cw avx /proc/cpuinfo` muss größer als 0 sein.

---

## 8. Quick Reference

### 8.1 trmmctl

```bash
sudo trmmctl status            # Versionen, Container, Zertifikat, letztes Backup
sudo trmmctl up|down|restart   # Stack steuern
sudo trmmctl logs [dienst]     # z.B. logs init backend
sudo trmmctl update [version]  # Backup + neues Release
sudo trmmctl cert [domain]     # Zertifikat übernehmen + Neustart
sudo trmmctl backup            # Backup nach /var/backups/trmm
sudo trmmctl restore <datei>   # Backup einspielen
sudo trmmctl migrate-db        # alte DB-Volumes übernehmen
sudo trmmctl doctor            # Systemcheck
sudo trmmctl createsuperuser   # weiterer Admin
sudo trmmctl compose <args>    # beliebiger docker compose Befehl
```

### 8.2 Docker Befehle (im Projekt)

```bash
cd /opt/trmm
sudo docker compose ps               # Status
sudo docker compose logs -f          # Live-Logs
sudo docker compose exec <svc> sh    # Shell in Container
```

### 8.3 Certbot

```bash
# Neues Wildcard-Zertifikat
sudo certbot certonly --manual -d "*.domain.de" \
  --agree-tos --preferred-challenges dns

# Zertifikate auflisten
sudo certbot certificates
```

### 8.4 Systemzeit

```bash
timedatectl                   # Status anzeigen
sudo timedatectl set-ntp true # NTP aktivieren
```

### 8.5 Wichtige Pfade

Siehe [1.4 Verzeichnisse auf dem Server](#14-verzeichnisse-auf-dem-server).

---

## Anhang: Key Learnings

1. **Systemzeit ist kritisch** - Vor jeder Installation prüfen (macht der Installer)!
2. **Docker aus dem offiziellen Repository** - nicht das alte `docker-compose` v1
3. **TRMM Init dauert** - 5-10 Minuten Geduld
4. **Pi-hole kann blockieren** - Whitelist für Docker/GitHub/Mirrors
5. **Pattern Matching > apt-upgrade** - Für Paket-Kategorisierung zuverlässiger
6. **Farben auto-detect** - Für TRMM-Kompatibilität
7. **AVX für MongoDB** - Proxmox CPU-Typ `host`
8. **Major-Versionen von Datenbanken nie "einfach hochdrehen"** - immer Dump/Restore (`trmmctl migrate-db`)

---

*Dokumentation erstellt: Februar 2026, überarbeitet Oktober 2026*  
*Phydran6*
