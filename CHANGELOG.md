# Changelog

Alle wichtigen Änderungen an diesem Projekt werden in dieser Datei dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.0.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Geplant
- Automatische Zertifikat-Erneuerung (DNS-API, z.B. Cloudflare)
- Integration mit zusätzlichen Monitoring-Tools
- Support für Rocky Linux / AlmaLinux

## [2.0.0] - 2026-10-25

### Added
- Online-Installer: `curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh | sudo bash`
  - installiert Docker aus dem offiziellen Repository, legt `/opt/trmm/.env` mit Zufallspasswörtern an, pinnt das aktuelle TRMM-Release
  - übernimmt bestehende Installationen aus `~/trmm` / `~/tactical-rmm` inkl. Datenbank-Migration
  - `--tools-only` für Server ohne TRMM, `--uninstall`
  - bricht ohne AVX-fähige CPU (MongoDB 8.0) ab, bevor etwas am System verändert wird
- `trmmctl`: status, up/down/restart, logs, update, cert, backup, restore, migrate-db, doctor, self-update
- `opt/trmm/docker-compose.yml` mit PostgreSQL 18, Redis 8, MongoDB 8.0 (statt 13 / 6.0 / 4.4, alle EOL), Healthchecks, Log-Rotation
- systemd-Timer `trmm-backup.timer` und `update-check.timer` (ersetzt den Cron-Job), logrotate

### Changed
- Repo-Layout entspricht den Zielpfaden (FHS): `usr/local/bin`, `usr/local/sbin`, `etc/`, `opt/trmm`
- Scripts ohne `.sh` im PATH (`update-check.sh` / `server-update.sh` bleiben als Symlink)
- `Linux - Patch Check` → `apt-smart-update`, `Linux - Debain Fesplatte erweitern` → `pve-disk-resize`
- Docker-Engine-Pakete werden nicht mehr automatisch aktualisiert (Neustart aller Container)
- GitHub-Workflows/Templates nach `.github/` verschoben (wurden vorher nicht ausgeführt)

### Fixed
- `apt-smart-update` brach ohne verfügbare Updates still ab (`set -e` + `pipefail`)
- `apt-smart-update` wertete Installationsfehler nie aus (`$?` nach `set -e`)
- Update-Scripts markierten Abhängigkeiten als „manuell installiert“ (`autoremove` griff nicht mehr)
- Unbeaufsichtigte Updates konnten an Conffile-Dialogen hängen (`DEBIAN_FRONTEND=noninteractive`)
- `pve-disk-resize` war fest auf `/dev/sda` verdrahtet (jetzt auch `vda`, `nvme`)
- Dokumentation: doppelt kodierte Umlaute repariert

## [1.0.0] - 2026-02-01

### Added
- Initial Release
- `update-check.sh` - Script zur Update-Prüfung mit Kategorisierung
- `server-update.sh` - Script zur automatischen Installation unkritischer Updates
- Vollständige Homelab-Infrastruktur Dokumentation
- Tactical RMM Docker Deployment Anleitung
- SSL-Zertifikat Management via Certbot
- Pi-hole Konfigurations-Guidelines
- Troubleshooting-Dokumentation
- Quick Reference Guide

### Features
- Automatische Kategorisierung von Updates (KRITISCH/MITTEL/NIEDRIG)
- Sichere automatische Installation unkritischer Pakete
- Manuelle Kontrolle über kritische System-Updates
- Docker Compose v2 Installation Guide
- Wildcard SSL-Zertifikate Setup
- MeshCentral Remote Access Integration
- Nginx Proxy Manager Konfiguration

### Documentation
- Vollständige Markdown-Dokumentation
- PDF-Version der Dokumentation
- README mit Quick Start Guide
- Contribution Guidelines
- MIT License

## Versionshistorie

### Version Nummern Erklärung

- **MAJOR** (1.x.x): Breaking Changes, große neue Features
- **MINOR** (x.1.x): Neue Features, abwärtskompatibel
- **PATCH** (x.x.1): Bugfixes, kleine Verbesserungen

[Unreleased]: https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/compare/v1.0.0...v2.0.0
[1.0.0]: https://github.com/Phydran6/Homelab-RMM-Tactical-RMM/releases/tag/v1.0.0
