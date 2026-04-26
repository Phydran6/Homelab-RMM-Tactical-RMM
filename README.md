# Homelab Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-12-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![ShellCheck](https://github.com/yourusername/homelab-infrastructure/workflows/ShellCheck/badge.svg)](https://github.com/yourusername/homelab-infrastructure/actions)
[![GitHub release](https://img.shields.io/github/v/release/yourusername/homelab-infrastructure)](https://github.com/yourusername/homelab-infrastructure/releases)
[![GitHub stars](https://img.shields.io/github/stars/yourusername/homelab-infrastructure)](https://github.com/yourusername/homelab-infrastructure/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/yourusername/homelab-infrastructure)](https://github.com/yourusername/homelab-infrastructure/issues)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

**Automatisierte System-Verwaltung und Monitoring für Homelab-Umgebungen**

Entwickelt von [Phydran6](https://github.com/Phydran6)

---

## 📋 Übersicht

Dieses Repository enthält eine vollständige Dokumentation und Automatisierungs-Scripts für den Aufbau einer professionellen Homelab-Infrastruktur mit Fokus auf:

- 🎯 **Zentrales System-Monitoring** via Tactical RMM
- 🔄 **Intelligentes Update-Management** mit automatischer Risiko-Kategorisierung
- 🐳 **Container-basierte Service-Deployment** mit Docker
- 🔐 **SSL-Automatisierung** via Let's Encrypt Wildcard-Zertifikate

## ✨ Features

### Update-Management Scripts
- ✅ **Automatische Installation** unkritischer Updates
- ⚠️ **Manuelle Kontrolle** für kritische Pakete (Kernel, SSL, Auth)
- 📊 **Kategorisierung** nach Risiko-Level (KRITISCH/MITTEL/NIEDRIG)
- 🔒 **Sicherheits-First** Ansatz bei System-Updates
- 📝 **Detaillierte Logging** aller Update-Vorgänge

### Tactical RMM Deployment
- 🐳 **Docker-basiert** - Einfache Installation und Wartung
- 🔐 **SSL/TLS** - Wildcard-Zertifikate via Certbot
- 🌐 **Multi-Domain Setup** - rmm/api/mesh Subdomains
- 📱 **Remote Management** - MeshCentral Integration
- 🔄 **Auto-Deploy** - Infrastructure as Code

### Infrastruktur
- 🖥️ **Proxmox** Virtualisierung
- 🐧 **Debian 12** (Bookworm)
- 🔍 **Pi-hole** DNS-Filtering
- 🔄 **Nginx Proxy Manager** Reverse Proxy

## 🚀 Quick Start

### One-Line Installation

```bash
git clone https://github.com/Phydran6/Homelab-RMM-Tactical-RMM.git && \
cd Homelab-RMM-Tactical-RMM.git && \
sudo ./install.sh
```

### Manuelle Installation

1. **Repository klonen**
```bash
git clone https://github.com/Phydran6/Homelab-RMM-Tactical-RMM.git
cd homelab-infrastructure
```

2. **Update-Scripts installieren**
```bash
sudo cp scripts/update-check.sh /usr/local/bin/
sudo cp scripts/server-update.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/update-check.sh
sudo chmod +x /usr/local/bin/server-update.sh
```

3. **Updates prüfen**
```bash
update-check.sh
```

4. **Automatisch updaten**
```bash
sudo server-update.sh
```

## 📖 Dokumentation

Die vollständige Dokumentation findest du in [`docs/Homelab-Infrastructure-Dokumentation.md`](docs/Homelab-Infrastructure-Dokumentation.md)

### 📚 Inhaltsverzeichnis:
1. [Übersicht](docs/Homelab-Infrastructure-Dokumentation.md#1-übersicht)
2. [Docker Installation auf Debian 12](docs/Homelab-Infrastructure-Dokumentation.md#2-docker-installation-auf-debian-12)
3. [Tactical RMM Docker Deployment](docs/Homelab-Infrastructure-Dokumentation.md#3-tactical-rmm-docker-deployment)
4. [SSL-Zertifikate mit Certbot](docs/Homelab-Infrastructure-Dokumentation.md#4-ssl-zertifikate-mit-certbot)
5. [Update-Management Scripts](docs/Homelab-Infrastructure-Dokumentation.md#5-update-management-scripts)
6. [Pi-hole Konfiguration](docs/Homelab-Infrastructure-Dokumentation.md#6-pi-hole-konfiguration)
7. [Troubleshooting](docs/Homelab-Infrastructure-Dokumentation.md#7-troubleshooting)
8. [Quick Reference](docs/Homelab-Infrastructure-Dokumentation.md#8-quick-reference)

## 🛠️ Wartung & Updates

Schritt-für-Schritt-Anleitungen für wiederkehrende Wartungsaufgaben:

| Anleitung | Beschreibung |
|-----------|--------------|
| [01 – SSL-Zertifikat erneuern](wartung/01-ssl-zertifikat-erneuern.md) | Wildcard-Zertifikat mit Certbot erneuern und in TRMM & NPM eintragen |
| [02 – TRMM Update](wartung/02-trmm-update.md) | Tactical RMM Docker-Installation aktualisieren |

---

## 🔧 Update-Scripts

### `update-check.sh` - Update-Prüfung

Prüft verfügbare Updates und kategorisiert sie nach Priorität.

**Verwendung:**
```bash
update-check.sh
```

**Beispiel-Ausgabe:**
```
24 UPDATE(S)
----------------
KRITISCH: linux-image-amd64 openssl libssl3
MITTEL: systemd base-files
NIEDRIG: vim curl nginx
```

### `server-update.sh` - Automatische Installation

Installiert automatisch unkritische Updates, zeigt kritische Pakete zur manuellen Installation.

**Verwendung:**
```bash
sudo server-update.sh
```

**Beispiel-Ausgabe:**
```
=> installiere 12 unkritische(s) paket(e)...

========================================
KRITISCHE UPDATES - MANUELLE INSTALLATION
========================================
  linux-image-6.1.0-18-amd64
    -> sudo apt install linux-image-6.1.0-18-amd64
  
Alle kritischen auf einmal:
  -> sudo apt install linux-image-6.1.0-18-amd64 systemd

========================================
ZUSAMMENFASSUNG
========================================
Installiert:     12 paket(e)
Uebersprungen:   2 paket(e) (kritisch)
```

## 📊 Update-Kategorisierung

| Priorität | Pakete | Aktion |
|-----------|--------|--------|
| **🔴 KRITISCH** | Kernel, SSL, Auth, Security-Updates | Manuelle Installation erforderlich |
| **🟡 MITTEL** | Systemd, Netzwerk, Paketmanager | Zeitnahe Installation empfohlen |
| **🟢 NIEDRIG** | Normale Anwendungen, Libraries | Automatische Installation |

### Kritische Pakete (Pattern):
- `linux-image-*`, `linux-headers-*`
- `openssl`, `libssl*`, `libcrypto*`
- `grub*`, `initramfs*`, `efi*`
- `sudo`, `openssh*`, `libpam-*`
- `systemd*`, `libc6`, `bash`

## 🐳 Tactical RMM Setup (Kurzform)

```bash
# 1. Docker installieren
sudo apt install docker.io
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# 2. Wildcard-Zertifikat erstellen
sudo apt install certbot
sudo certbot certonly --manual -d *.yourdomain.com --agree-tos --no-bootstrap --preferred-challenges dns

# 3. TRMM Setup
mkdir ~/tactical-rmm && cd ~/tactical-rmm
wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/docker-compose.yml
wget https://raw.githubusercontent.com/amidaware/tacticalrmm/master/docker/.env.example
mv .env.example .env

# 4. Zertifikate in .env eintragen
echo "CERT_PUB_KEY=$(sudo base64 -w 0 /etc/letsencrypt/live/yourdomain.com/fullchain.pem)" >> .env
echo "CERT_PRIV_KEY=$(sudo base64 -w 0 /etc/letsencrypt/live/yourdomain.com/privkey.pem)" >> .env

# 5. .env anpassen, dann starten
nano .env  # APP_HOST, API_HOST, MESH_HOST anpassen
docker compose up -d
```

📖 **Vollständige Anleitung:** [docs/Homelab-Infrastructure-Dokumentation.md](docs/Homelab-Infrastructure-Dokumentation.md#3-tactical-rmm-docker-deployment)

## 🔒 Sicherheit

- **Keine automatischen Kernel-Updates** - Verhindert unerwartete Reboots
- **SSL/Auth-Updates manuell** - Maximale Kontrolle über kritische Komponenten
- **Security-Updates priorisiert** - Werden als KRITISCH kategorisiert
- **Audit-Trail** - Alle Updates werden geloggt
- **ShellCheck** - Alle Scripts werden validiert

📋 **Security Policy:** [SECURITY.md](SECURITY.md)

## 🛠️ Systemanforderungen

- **OS:** Debian 12 (Bookworm) oder Ubuntu 22.04+
- **RAM:** Minimum 4GB (8GB empfohlen für TRMM)
- **Disk:** 20GB+ freier Speicher
- **CPU:** 2+ Cores
- **Netzwerk:** Statische IP empfohlen

## 📁 Projektstruktur

```
homelab-infrastructure/
├── 📄 README.md                      # Diese Datei
├── 📄 LICENSE                        # MIT License
├── 📄 CHANGELOG.md                   # Versionshistorie
├── 📄 CONTRIBUTING.md                # Contribution Guidelines
├── 📄 CODE_OF_CONDUCT.md            # Code of Conduct
├── 📄 SECURITY.md                    # Security Policy
├── 🔧 install.sh                     # Quick Install Script
├── 📂 wartung/                       # Wartungs- & Update-Anleitungen
│   ├── 📖 01-ssl-zertifikat-erneuern.md
│   └── 📖 02-trmm-update.md
├── 📂 scripts/
│   ├── 📜 update-check.sh           # Update-Prüfung
│   └── 📜 server-update.sh          # Automatische Installation
├── 📂 docs/
│   ├── 📖 Homelab-Infrastructure-Dokumentation.md
│   └── 📄 Homelab-Infrastructure-Dokumentation.pdf
└── 📂 .github/
    ├── 📂 workflows/
    │   ├── shellcheck.yml           # Script-Validierung
    │   ├── test.yml                 # Automated Testing
    │   └── release.yml              # Release Automation
    └── 📂 ISSUE_TEMPLATE/
        ├── bug_report.md
        └── feature_request.md
```

## 🤝 Beitragen

Contributions sind willkommen! 🎉

1. Fork das Repository
2. Erstelle einen Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit deine Änderungen (`git commit -m 'Add some AmazingFeature'`)
4. Push zum Branch (`git push origin feature/AmazingFeature`)
5. Öffne einen Pull Request

📖 **Contribution Guide:** [CONTRIBUTING.md](CONTRIBUTING.md)

## 📝 License

Dieses Projekt ist unter der MIT License lizenziert - siehe [LICENSE](LICENSE) Datei für Details.

## 👤 Autor

**Phydran6**
- 💼 GitHub: [@Phydran6](https://github.com/Phydran6)

## 📚 Weitere Ressourcen

- 📖 [Tactical RMM Dokumentation](https://docs.tacticalrmm.com/)
- 🐳 [Docker Compose Dokumentation](https://docs.docker.com/compose/)
- 🔐 [Certbot Dokumentation](https://certbot.eff.org/docs/)
- 🖥️ [Proxmox Dokumentation](https://pve.proxmox.com/wiki/Main_Page)

## ⚠️ Wichtige Hinweise

- ⏰ **Systemzeit muss korrekt sein** vor Paket-Installation
- 🐳 **Docker Compose v2 Plugin** manuell installieren (nicht Debian-Paket)
- ⏳ **TRMM Initialisierung** dauert 5-10 Minuten
- 👤 **User-Erstellung** via Shell, nicht Web-UI
- 🔍 **Pi-hole Whitelist** für Docker/GitHub/APT-Mirrors notwendig

## 📊 Status & Roadmap

### ✅ Aktueller Status
- Aktiv in Produktion seit Februar 2026
- Tested auf Debian 12 & Ubuntu 22.04
- ShellCheck validated

### 🗺️ Roadmap
- [ ] Automatische Zertifikat-Erneuerung
- [ ] Backup-Scripts für TRMM
- [ ] Support für Rocky Linux / AlmaLinux
- [ ] Grafana Dashboard Integration
- [ ] Email-Benachrichtigungen bei kritischen Updates

---

<div align="center">

**⭐ Wenn dir dieses Projekt geholfen hat, gib ihm einen Star!**

Made with ❤️ by [Phydran6](https://github.com/Phydran6)

[Report Bug](https://github.com/yourusername/homelab-infrastructure/issues) • [Request Feature](https://github.com/yourusername/homelab-infrastructure/issues) • [Documentation](docs/Homelab-Infrastructure-Dokumentation.md)

</div>
