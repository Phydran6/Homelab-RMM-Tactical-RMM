# HOMELAB INFRASTRUCTURE DOKUMENTATION

**Phydran6**  
**Stand: Februar 2026**

---

## Inhaltsverzeichnis

1. [Ãœbersicht](#1-Ã¼bersicht)
2. [Docker Installation auf Debian 12](#2-docker-installation-auf-debian-12)
3. [Tactical RMM Docker Deployment](#3-tactical-rmm-docker-deployment)
4. [SSL-Zertifikate mit Certbot](#4-ssl-zertifikate-mit-certbot)
5. [Update-Management Scripts](#5-update-management-scripts)
6. [Pi-hole Konfiguration](#6-pi-hole-konfiguration)
7. [Troubleshooting](#7-troubleshooting)
8. [Quick Reference](#8-quick-reference)

---

## 1. Ãœbersicht

Diese Dokumentation beschreibt die Einrichtung und Wartung der Homelab-Infrastruktur mit Fokus auf System-Automatisierung und Monitoring.

### 1.1 Kernkomponenten

- **Tactical RMM (TRMM)** - System Monitoring und Remote Management
- **Docker** - Container-Plattform fÃ¼r alle Services
- **Nginx Proxy Manager** - SSL-Terminierung und Reverse Proxy
- **Pi-hole** - DNS-Filtering
- **Certbot** - Let's Encrypt Wildcard-Zertifikate
- **Custom Update Scripts** - Automatisierte Paketverwaltung

### 1.2 Domain-Struktur

**Hauptdomain:** phytech.de

| Subdomain | Zweck |
|-----------|-------|
| rmm.phytech.de | Tactical RMM Frontend |
| api.phytech.de | Tactical RMM API |
| mesh.phytech.de | MeshCentral Remote Access |

### 1.3 Infrastruktur

- **Virtualisierung:** Proxmox
- **Betriebssystem:** Debian 12 (Bookworm)
- **DNS-Server:** Pi-hole (192.168.179.30)

---

## 2. Docker Installation auf Debian 12

> **âš ï¸ WICHTIG:** Nicht das Debian-Paket `docker-compose` verwenden! Stattdessen manuelles Docker Compose v2 Plugin installieren.

### 2.1 Docker Engine installieren

```bash
# NUR docker.io installieren (NICHT docker-compose!)
sudo apt update
sudo apt install docker.io
```

### 2.2 Docker Compose v2 Plugin manuell hinzufÃ¼gen

```bash
# Plugin-Verzeichnis erstellen
sudo mkdir -p /usr/local/lib/docker/cli-plugins

# Docker Compose herunterladen
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose

# AusfÃ¼hrbar machen
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Testen
docker compose version
```

### 2.3 User zur Docker-Gruppe hinzufÃ¼gen

```bash
sudo usermod -aG docker $USER
# Danach neu anmelden!
```

---

## 3. Tactical RMM Docker Deployment

**Offizielle Dokumentation:** https://docs.tacticalrmm.com/install_docker/

### 3.1 Voraussetzungen

- 3 DNS A-Records: `rmm`, `api`, `mesh` â†’ Server-IP
- Wildcard SSL-Zertifikat (*.phytech.de)
- Docker + Docker Compose v2 Plugin
- Port 443 in Firewall geÃ¶ffnet

### 3.2 Zertifikat mit Certbot erstellen

```bash
sudo apt install certbot

# Wildcard-Zertifikat anfordern (DNS-01 Challenge)
sudo certbot certonly --manual -d *.phytech.de \
  --agree-tos --no-bootstrap --preferred-challenges dns
```

Bei der Aufforderung: TXT-Record `_acme-challenge.phytech.de` im DNS-Manager eintragen.

```bash
# Verifizieren dass TXT-Record propagiert ist
dig -t txt _acme-challenge.phytech.de
```

> **Erst nach erfolgreicher Verifikation Enter drÃ¼cken!**

### 3.3 TRMM Dateien herunterladen

```bash
mkdir -p ~/tactical-rmm && cd ~/tactical-rmm

wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/docker-compose.yml
wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/.env.example
mv .env.example .env
```

### 3.4 Zertifikate Base64-kodieren und eintragen

```bash
# Zertifikate in .env eintragen
echo "CERT_PUB_KEY=$(sudo base64 -w 0 /etc/letsencrypt/live/phytech.de/fullchain.pem)" >> .env
echo "CERT_PRIV_KEY=$(sudo base64 -w 0 /etc/letsencrypt/live/phytech.de/privkey.pem)" >> .env
```

### 3.5 .env anpassen

```bash
nano .env
```

Wichtige Werte:
```
APP_HOST=rmm.phytech.de
API_HOST=api.phytech.de
MESH_HOST=mesh.phytech.de
TRMM_USER=admin
TRMM_PASS=<sicheres-passwort>
```

### 3.6 Container starten

```bash
docker compose up -d

# Logs beobachten (Init dauert 5-10 Minuten!)
docker compose logs -f
```

> **âš ï¸ WICHTIG:** Die Initialisierung der Container dauert **5-10 Minuten**. Geduld!

### 3.7 User-Erstellung via Shell

User-Erstellung Ã¼ber Web-UI funktioniert bei Docker manchmal nicht korrekt. Besser Ã¼ber Shell:

```bash
# In Django Shell einloggen
sudo docker exec -it trmm-backend python manage.py shell
```

```python
# Python-Befehle:
from accounts.models import User
User.objects.create_superuser('admin', 'admin@example.com', 'password')
exit()
```

### 3.8 NPM (Nginx Proxy Manager) Konfiguration

Falls NPM als Reverse Proxy verwendet wird, alle 3 Proxy Hosts auf Port 80 der TRMM-Box zeigen lassen:

| Domain | Forward Port | WebSocket |
|--------|-------------|-----------|
| rmm.phytech.de | 80 | ON |
| api.phytech.de | 80 | OFF |
| mesh.phytech.de | 80 | ON |

SSL: Wildcard-Zertifikat `*.phytech.de`, Force SSL ON

---

## 4. SSL-Zertifikate mit Certbot

### 4.1 Zertifikat-Speicherort

```
/etc/letsencrypt/live/phytech.de/
â”œâ”€â”€ fullchain.pem   # Ã–ffentlicher SchlÃ¼ssel + Zertifikatskette
â”œâ”€â”€ privkey.pem     # Privater SchlÃ¼ssel
â”œâ”€â”€ cert.pem        # Nur das Zertifikat
â””â”€â”€ chain.pem       # Nur die Kette
```

### 4.2 Zertifikat erneuern

```bash
sudo certbot renew
```

> Nach Erneuerung: `.env` aktualisieren und Container neu starten!

### 4.3 Neues Zertifikat fÃ¼r andere Domain

```bash
sudo certbot certonly --manual -d *.neue-domain.de \
  --agree-tos --no-bootstrap --preferred-challenges dns
```

---

## 5. Update-Management Scripts

Zwei komplementÃ¤re Scripts fÃ¼r sichere System-Updates mit automatischer Kategorisierung.

### 5.1 Kategorisierung

| PrioritÃ¤t | Beschreibung | Aktion |
|-----------|--------------|--------|
| **KRITISCH** (rot) | Security, Kernel, SSL, Auth | Manuelle Installation |
| **MITTEL** (gelb) | Systemd, Netzwerk, Core | Zeitnah installieren |
| **NIEDRIG** (grÃ¼n) | Alles andere | Automatisch installierbar |

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

**NIEDRIG - Pakete:**
- Normale Anwendungen
- Unkritische Libraries

### 5.2 update-check.sh - Nur prÃ¼fen

```bash
#!/bin/bash
# ==============================================================================
# update-check.sh
# Prueft auf Updates und kategorisiert nach Prioritaet
# ==============================================================================
# Autor:    Phydran6
# Version:  2026-01-05
# System:   Debian/Ubuntu
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
```

### 5.3 server-update.sh - Automatisch installieren

Installiert automatisch nur unkritische Pakete, zeigt kritische mit Installationsbefehl an.

```bash
#!/bin/bash
# ==============================================================================
# server-update.sh
# Installiert unkritische Updates automatisch, kritische manuell
# ==============================================================================
# Autor:    Phydran6
# Version:  2026-01-05
# System:   Debian/Ubuntu
# ==============================================================================

# kritische pakete pattern
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
    apt-get install -y "${AUTO[@]}" 2>&1 | grep -E "^(Inst|Conf)"
fi

# kritische anzeigen
if [ ${#MANUELL[@]} -gt 0 ]; then
    echo ""
    echo "========================================"
    echo "KRITISCHE UPDATES - MANUELLE INSTALLATION"
    echo "========================================"
    for pkg in "${MANUELL[@]}"; do
        echo "  $pkg"
        echo "    -> sudo apt install $pkg"
    done
    echo ""
    echo "Alle kritischen auf einmal:"
    echo "  -> sudo apt install ${MANUELL[*]}"
fi

# zusammenfassung
echo ""
echo "========================================"
echo "ZUSAMMENFASSUNG"
echo "========================================"
echo "Installiert:     ${#AUTO[@]} paket(e)"
echo "Uebersprungen:   ${#MANUELL[@]} paket(e) (kritisch)"
```

### 5.4 Beispiel-Ausgabe update-check.sh

```
24 UPDATE(S)
----------------
KRITISCH: linux-image-amd64 openssl libssl3
MITTEL: systemd base-files
NIEDRIG: vim curl nginx
```

### 5.5 Beispiel-Ausgabe server-update.sh

```
=> paketlisten aktualisieren...
=> installiere 12 unkritische(s) paket(e)...

========================================
KRITISCHE UPDATES - MANUELLE INSTALLATION
========================================
  linux-image-6.1.0-18-amd64
    -> sudo apt install linux-image-6.1.0-18-amd64
  systemd
    -> sudo apt install systemd

Alle kritischen auf einmal:
  -> sudo apt install linux-image-6.1.0-18-amd64 systemd

========================================
ZUSAMMENFASSUNG
========================================
Installiert:     12 paket(e)
Uebersprungen:   2 paket(e) (kritisch)
```

---

## 6. Pi-hole Konfiguration

Pi-hole kann Docker/GitHub/Debian Mirrors blockieren. Whitelist-EintrÃ¤ge nÃ¶tig.

### 6.1 Wichtige Whitelist-Domains

```
# Docker
docker.com
docker.io
registry.hub.docker.com
hub.docker.com
auth.docker.io
registry-1.docker.io

# GitHub
github.com
githubusercontent.com
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

# NPM (falls benÃ¶tigt)
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

Wenn `apt update` fehlschlÃ¤gt und Domains auf `127.0.0.1` aufgelÃ¶st werden â†’ Pi-hole blockiert!

**LÃ¶sung:** Domains in Pi-hole Whitelist eintragen.

---

## 7. Troubleshooting

### 7.1 VM-Zeit falsch - APT schlÃ¤gt fehl

**Symptom:** `Release-Datei ist noch nicht gÃ¼ltig`

```bash
# Systemzeit synchronisieren
sudo timedatectl set-ntp true
sleep 5
date

# Falls timedatectl nicht verfÃ¼gbar
sudo apt install ntpdate
sudo ntpdate -s ntp.ubuntu.com

# APT mit deaktivierter ZeitprÃ¼fung
sudo apt-get update -o Acquire::Check-Valid-Until=false
```

> **âš ï¸ WICHTIG:** Systemzeit MUSS korrekt sein bevor Pakete installiert werden!

### 7.2 Docker Netzwerk-Konflikte

```bash
# Alle Container stoppen
docker compose down

# Docker Netzwerke aufrÃ¤umen
docker network prune -f

# Neu starten
docker compose up -d
```

### 7.3 TRMM Init-Container hÃ¤ngt

Die Initialisierung dauert 5-10 Minuten. Geduld!

```bash
# Logs beobachten
docker compose logs -f

# Falls nach 15min noch nichts:
docker compose down -v
docker compose up -d
```

### 7.4 ANSI-Farbcodes im Terminal

Scripts erkennen automatisch ob Terminal Farben unterstÃ¼tzt:

```bash
# Am Anfang jedes Scripts:
if [ -t 1 ] && [ "$(tput colors 2>/dev/null)" -ge 8 ]; then
    RED='\033[0;31m' GREEN='\033[0;32m' NC='\033[0m'
else
    RED='' GREEN='' NC=''
fi
```

### 7.5 .env Datei hat falsche Berechtigungen

```bash
# Besitzer Ã¤ndern
sudo chown $USER:$USER .env
sudo chmod 644 .env
```

### 7.6 Docker-Gruppe nicht aktiv

Nach `usermod -aG docker $USER` neu anmelden oder:

```bash
newgrp docker
```

---

## 8. Quick Reference

### 8.1 Docker Befehle

```bash
docker compose up -d        # Starten (detached)
docker compose down          # Stoppen
docker compose down -v       # Stoppen + Volumes lÃ¶schen
docker compose logs -f       # Live-Logs
docker compose ps            # Status
docker compose restart       # Neu starten
docker compose exec <svc> sh # Shell in Container
```

### 8.2 TRMM Container

```bash
# Django Shell fÃ¼r User-Management
sudo docker exec -it trmm-backend python manage.py shell

# User erstellen (in Shell)
from accounts.models import User
User.objects.create_superuser('admin', 'mail@domain.de', 'password')
exit()
```

### 8.3 Certbot

```bash
# Neues Wildcard-Zertifikat
sudo certbot certonly --manual -d *.domain.de \
  --agree-tos --no-bootstrap --preferred-challenges dns

# Zertifikate erneuern
sudo certbot renew

# Zertifikate auflisten
sudo certbot certificates
```

### 8.4 Systemzeit

```bash
timedatectl                  # Status anzeigen
sudo timedatectl set-ntp true # NTP aktivieren
date                         # Aktuelle Zeit
```

### 8.5 Wichtige Pfade

```
~/tactical-rmm/                      # TRMM Installation
~/tactical-rmm/.env                  # TRMM Konfiguration
~/tactical-rmm/docker-compose.yml

/etc/letsencrypt/live/phytech.de/    # SSL-Zertifikate
/usr/local/lib/docker/cli-plugins/   # Docker Compose Plugin
```

### 8.6 TRMM Docker Setup Kurzform

```bash
# 1. Docker installieren
sudo apt install docker.io
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 2. Certbot Wildcard-Cert
sudo apt install certbot
sudo certbot certonly --manual -d *.phytech.de --agree-tos --no-bootstrap --preferred-challenges dns

# 3. TRMM Setup
mkdir ~/tactical-rmm && cd ~/tactical-rmm
wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/docker-compose.yml
wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/.env.example
mv .env.example .env

# 4. Certs in .env
echo "CERT_PUB_KEY=$(sudo base64 -w 0 /etc/letsencrypt/live/phytech.de/fullchain.pem)" >> .env
echo "CERT_PRIV_KEY=$(sudo base64 -w 0 /etc/letsencrypt/live/phytech.de/privkey.pem)" >> .env

# 5. .env anpassen, dann starten
docker compose up -d

# 6. User via Shell erstellen (Init dauert 5-10min!)
sudo docker exec -it trmm-backend python manage.py shell
# from accounts.models import User
# User.objects.create_superuser('admin', 'admin@example.com', 'pass')
```

---

## Anhang: Key Learnings

1. **Systemzeit ist kritisch** - Vor jeder Installation prÃ¼fen!
2. **Docker Compose v2** - Manuelles Plugin, nicht Debian-Paket
3. **TRMM Init dauert** - 5-10 Minuten Geduld
4. **User nur via Shell** - Web-UI funktioniert bei Docker nicht zuverlÃ¤ssig
5. **Pi-hole kann blockieren** - Whitelist fÃ¼r Docker/GitHub/Mirrors
6. **Pattern Matching > apt-upgrade** - FÃ¼r Paket-Kategorisierung zuverlÃ¤ssiger
7. **Farben auto-detect** - FÃ¼r TRMM-KompatibilitÃ¤t

---

*Dokumentation erstellt: Februar 2026*  
*Phydran6*
