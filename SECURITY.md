# Security Policy

## 🔒 Sicherheitsrichtlinien

Die Sicherheit dieses Projekts wird ernst genommen. Wir schätzen die Bemühungen von Sicherheitsforschern und der Community, Schwachstellen verantwortungsvoll offenzulegen.

## 🛡️ Unterstützte Versionen

Wir bieten Sicherheitsupdates für die folgenden Versionen:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## 🚨 Sicherheitslücke melden

**Bitte melde Sicherheitslücken NICHT über öffentliche GitHub Issues.**

Wenn du eine Sicherheitslücke entdeckt hast, kontaktiere uns bitte direkt:

### Kontakt

- **GitHub:** [@Phydran6](https://github.com/Phydran6)
- **Betreff:** `[SECURITY] Vulnerability in Homelab-RMM-Tactical-RMM`

### Was solltest du in deinem Bericht angeben?

Bitte gib so viele der folgenden Informationen wie möglich an:

1. **Beschreibung der Schwachstelle**
   - Art der Schwachstelle (z.B. Code Injection, Privilege Escalation)
   - Betroffene Komponente(n)
   
2. **Schritte zur Reproduktion**
   - Detaillierte Anleitung wie die Schwachstelle ausgenutzt werden kann
   - Proof of Concept (falls verfügbar)

3. **Auswirkungen**
   - Welche Systeme/Daten sind betroffen?
   - Worst-Case-Szenario

4. **Vorgeschlagene Lösung** (optional)
   - Deine Ideen für einen Fix

5. **Deine Kontaktinformationen**
   - Für Rückfragen und Credit

### Was passiert nach dem Report?

1. **Bestätigung** innerhalb von 48 Stunden
2. **Erste Einschätzung** innerhalb von 7 Tagen
3. **Regelmäßige Updates** zum Status
4. **Koordinierte Veröffentlichung** eines Fixes
5. **Credit** für die Entdeckung (falls gewünscht)

## 🔐 Sicherheits-Best-Practices

### Für Nutzer

1. **Aktualisiere regelmäßig**
   ```bash
   sudo trmmctl self-update     # Scripts + Compose-File
   sudo trmmctl update          # Tactical RMM
   ```

2. **Prüfe Scripts vor Ausführung**
   ```bash
   curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh -o install.sh
   less install.sh               # Code Review vor "sudo bash install.sh"
   shellcheck install.sh usr/local/bin/* usr/local/sbin/*
   ```

3. **Minimale Berechtigungen**
   - Führe Scripts mit minimalen Rechten aus
   - Nutze `sudo` nur wenn nötig

4. **Sensitive Daten schützen**
   - Speichere keine Passwörter in Scripts
   - Nutze `.env` Dateien für Credentials (`/opt/trmm/.env` hat Rechte 600)
   - Füge `.env` zur `.gitignore` hinzu

5. **Backup vor Updates**
   ```bash
   sudo trmmctl backup          # DB, MeshCentral, Zertifikate, .env
   sudo cp -r /etc/letsencrypt /var/backups/
   ```

### Für Contributors

1. **Keine Secrets committen**
   - API Keys
   - Passwörter
   - Private Keys
   - IP Adressen
   - Domain Names (nutze Platzhalter)

2. **Input Validation**
   - Validiere alle User Inputs
   - Sanitize Shell-Variablen
   - Nutze `"${VAR}"` statt `$VAR`

3. **Sichere Defaults**
   - Restrictive Permissions
   - HTTPS only
   - Strong Authentication

4. **Code Review**
   - Lass deinen Code reviewen
   - Nutze ShellCheck
   - Teste auf isolierten Systemen

## 🎯 Scope

### Im Scope

- `install.sh` und Scripts unter `usr/local/`
- `opt/trmm/docker-compose.yml`
- Dokumentation die zu unsicheren Konfigurationen führen könnte
- Dependencies mit bekannten CVEs

### Außerhalb des Scope

- Schwachstellen in third-party Software (Tactical RMM, Docker, etc.)
  → Bitte direkt an die jeweiligen Projekte melden
- Social Engineering
- Physical Security
- DDoS-Angriffe

## 📋 Bekannte Einschränkungen

1. **Scripts benötigen sudo-Rechte**
   - Notwendig für Paket-Installation
   - Sicherstellen: Script-Quelle ist vertrauenswürdig

2. **Keine automatische Cert-Renewal**
   - Manuelle Erneuerung erforderlich
   - Geplant für zukünftige Version

3. **Plaintext Logs**
   - APT-Output kann sensitive Infos enthalten
   - Log-Rotation empfohlen

## 🏆 Hall of Fame

Wir danken folgenden Personen für verantwortungsvolle Disclosure:

*Noch keine Einträge - Sei der Erste! 🎉*

## 📚 Weitere Ressourcen

- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [Debian Security](https://www.debian.org/security/)

## 📝 Updates dieser Policy

Diese Security Policy wird regelmäßig überprüft und aktualisiert.

**Letzte Aktualisierung:** 2026-02-01

---

**Danke für deine Hilfe, dieses Projekt sicherer zu machen! 🛡️**
