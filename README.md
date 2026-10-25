# Homelab RMM – Tactical RMM

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Debian](https://img.shields.io/badge/Debian-12%20%7C%2013-A81D33?logo=debian&logoColor=white)](https://www.debian.org/)
[![Docker](https://img.shields.io/badge/Docker-Compose%20v2-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![ShellCheck](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/actions/workflows/shellcheck.yml)
[![Test](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/actions/workflows/test.yml/badge.svg)](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/actions/workflows/test.yml)
[![GitHub release](https://img.shields.io/github/v/release/Phydran6/Homelab-RMM-Tactical-RMM)](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/releases)

**Tactical RMM per Docker mit einem Befehl installieren – plus Update-Management-Scripts für Homelab-Server.**

Entwickelt von [Phydran6](https://github.com/Phydran6)

---

## 🚀 Installation

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh | sudo bash
```

Der Installer fragt nach der Domain (ergibt `rmm.`, `api.`, `mesh.<domain>`) und erledigt den Rest:

- prüft System, RAM, Systemzeit (aktiviert NTP) und DNS (Pi-hole-Blockaden)
- bricht ab, wenn die CPU kein AVX hat (MongoDB 8.0) – vor jeder Änderung am System
- installiert Docker Engine + Compose v2 aus dem offiziellen Docker-Repository
- legt das Projekt unter **`/opt/trmm`** an, mit `.env` (Rechte 600) und zufälligen Passwörtern
- pinnt das aktuelle Tactical-RMM-Release und nutzt aktuelle Datenbank-Images
- übernimmt ein vorhandenes Let's-Encrypt-Zertifikat
- übernimmt eine bestehende Installation (`~/trmm`, `~/tactical-rmm`) inkl. Datenbank-Migration
- richtet tägliches Backup und optional einen täglichen Update-Check ein (systemd-Timer)

### Ohne Rückfragen

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh \
  | sudo bash -s -- --domain example.com --admin admin --yes
```

### Nur die Update-Scripts (z.B. für andere Server)

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh \
  | sudo bash -s -- --tools-only
```

### Erst ansehen, dann ausführen

```bash
curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh -o install.sh
less install.sh
sudo bash install.sh --help
```

| Option | Bedeutung |
|--------|-----------|
| `--domain DOMAIN` | Basis-Domain |
| `--admin NAME` | TRMM-Admin (Default `admin`) |
| `-y`, `--yes` | keine Rückfragen |
| `--tools-only` | nur Scripts, kein Docker/TRMM |
| `--no-start` | einrichten, nicht starten |
| `--skip-docker` | Docker-Installation überspringen |
| `--[no-]backup-timer` | tägliches Backup (Default an) |
| `--[no-]update-timer` | täglicher update-check (Default aus) |
| `--ref REF` | Branch/Tag für den Download |
| `--uninstall` | Scripts/Timer entfernen, Daten bleiben |

Erneut ausführen = Update der Scripts und des Compose-Files (`/opt/trmm/.env` bleibt unverändert). Kurzform: `sudo trmmctl self-update`.

---

## 📁 Wo liegt was auf dem Server?

Die Struktur des Repos entspricht 1:1 den Zielpfaden:

```
/opt/trmm/
├── docker-compose.yml         # verwaltet vom Installer
├── .env                       # Konfiguration + Passwörter (600, wird nie überschrieben)
└── .env.example
/usr/local/sbin/
├── trmmctl                    # Verwaltung der TRMM-Installation
├── server-update              # unkritische Updates automatisch
├── apt-smart-update           # Update mit Timeout-Menü (auch als TRMM-Script)
└── pve-disk-resize            # Root-Partition nach Disk-Vergrößerung erweitern
/usr/local/bin/
└── update-check               # Updates prüfen und kategorisieren
/etc/default/trmm              # Einstellungen für trmmctl
/etc/systemd/system/
├── trmm-backup.{service,timer}
└── update-check.{service,timer}
/etc/logrotate.d/homelab-rmm
/var/backups/trmm/             # Backups + Migrations-Dumps
```

---

## 🛠️ trmmctl

```bash
sudo trmmctl status            # Versionen, Container, Zertifikat, letztes Backup
sudo trmmctl logs init         # Init beobachten (erster Start 5-10 Minuten)
sudo trmmctl update            # Backup + neuestes TRMM-Release + Image-Cleanup
sudo trmmctl cert              # Let's-Encrypt-Zertifikat in .env übernehmen + Neustart
sudo trmmctl cert --export /root/npm-certs   # + npm-*.pem für Nginx Proxy Manager
sudo trmmctl backup            # DB + MeshCentral + Zertifikate
sudo trmmctl restore <datei>
sudo trmmctl migrate-db        # alte DB-Volumes in neue Major-Versionen übernehmen
sudo trmmctl doctor            # NTP, AVX, DNS/Pi-hole, Volumes, Zertifikat
sudo trmmctl createsuperuser
sudo trmmctl help
```

---

## 🐳 Images

| Dienst | Upstream-Compose | Hier | `.env` |
|--------|------------------|------|--------|
| Tactical RMM | `latest` | aktuelles Release gepinnt | `VERSION` |
| PostgreSQL | `postgres:13-alpine` (EOL) | `postgres:18-alpine` | `POSTGRES_VERSION` |
| Redis | `redis:6.0-alpine` (EOL) | `redis:8-alpine` | `REDIS_VERSION` |
| MongoDB | `mongo:4.4` (EOL) | `mongo:8.0` | `MONGO_VERSION` |

Außerdem: Healthchecks mit `depends_on`-Conditions, Log-Rotation pro Container, begrenzter MongoDB-Cache, kein `user: 1000` mehr für Redis/MongoDB (die offiziellen Images droppen Privilegien selbst).

Die Datenbank-Volumes tragen die Major-Version im Namen (`trmm_postgres18_data`). Ein Versionswechsel startet so nie auf einem leeren Volume – `trmmctl` verweigert den Start und verweist auf `trmmctl migrate-db` (Dump/Restore, das alte Volume bleibt als Rollback).

> ⚠️ **MongoDB ≥ 5.0 braucht AVX.** Unter Proxmox den CPU-Typ der VM auf `host` oder `x86-64-v3` stellen. Ohne AVX bricht der Installer ab, bevor er etwas verändert.

---

## 🔄 Update-Scripts

| Script | Beschreibung |
|--------|--------------|
| `update-check` | Prüft Updates und kategorisiert nach KRITISCH / MITTEL / NIEDRIG |
| `sudo server-update` | Installiert NIEDRIG automatisch, zeigt kritische mit Befehl an |
| `sudo apt-smart-update` | Wie server-update, mit 3-Sekunden-Timeout-Menü – läuft ohne Eingabe vollautomatisch (TRMM) |
| `sudo pve-disk-resize` | Erweitert die Root-Partition nach Vergrößerung der virtuellen Disk |

Beispiel `update-check`:
```
24 UPDATE(S)
----------------
KRITISCH: linux-image-amd64 openssl libssl3
MITTEL: systemd base-files docker-ce
NIEDRIG: vim curl nginx
```

| Priorität | Pakete | Aktion |
|-----------|--------|--------|
| **🔴 KRITISCH** | Kernel, SSL, Auth, Security-Updates | Manuelle Installation |
| **🟡 MITTEL** | systemd, Netzwerk, Paketmanager, Docker-Engine | Zeitnah manuell |
| **🟢 NIEDRIG** | Normale Anwendungen, Libraries | Automatisch |

Die Scripts installieren mit `--only-upgrade` ohne Dialoge (`DEBIAN_FRONTEND=noninteractive`, geänderte Config-Dateien bleiben) und erhalten die Auto-Markierung von Abhängigkeiten, damit `apt autoremove` weiter aufräumt. Details: [usr/local/README.md](usr/local/README.md)

---

## 📖 Dokumentation

| Dokument | Inhalt |
|----------|--------|
| [docs/Homelab-Infrastructure-Dokumentation.md](docs/Homelab-Infrastructure-Dokumentation.md) | Gesamtdokumentation: Installation, TRMM, SSL, Scripts, Pi-hole, Troubleshooting |
| [wartung/01 – SSL-Zertifikat erneuern](wartung/01-ssl-zertifikat-erneuern.md) | Wildcard-Zertifikat mit Certbot erneuern und in TRMM & NPM eintragen |
| [wartung/02 – TRMM Update](wartung/02-trmm-update.md) | Tactical RMM aktualisieren |

---

## 🛠️ Systemanforderungen

- **OS:** Debian 12/13 oder Ubuntu 22.04+ (amd64 für TRMM)
- **RAM:** Minimum 4 GB
- **Disk:** 20 GB+ frei
- **CPU:** 2+ Cores, mit AVX (Proxmox CPU-Typ `host`)
- **Netzwerk:** Statische IP, DNS A-Records `rmm`/`api`/`mesh`

## ⚠️ Wichtige Hinweise

- ⏰ **Systemzeit muss korrekt sein** – der Installer aktiviert NTP
- ⏳ **TRMM-Initialisierung** dauert 5-10 Minuten (`trmmctl logs init`)
- 🔍 **Pi-hole-Whitelist** für Docker/GitHub/APT-Mirrors notwendig – `trmmctl doctor` prüft das
- 🔐 **Agent-Auto-Update** vor einem TRMM-Update in der Web-UI deaktivieren

## 🗺️ Roadmap

- [x] Online-Installer
- [x] Backup-Scripts für TRMM
- [ ] Automatische Zertifikat-Erneuerung (DNS-API)
- [ ] Support für Rocky Linux / AlmaLinux
- [ ] Email-Benachrichtigungen bei kritischen Updates

---

## 🤝 Beitragen

Contributions sind willkommen – siehe [CONTRIBUTING.md](CONTRIBUTING.md). Sicherheitslücken bitte gemäß [SECURITY.md](SECURITY.md) melden.

## 📝 License

MIT – siehe [LICENSE](LICENSE).

<div align="center">

Made with ❤️ by [Phydran6](https://github.com/Phydran6)

[Report Bug](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/issues) • [Request Feature](https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/issues) • [Documentation](docs/Homelab-Infrastructure-Dokumentation.md)

</div>
