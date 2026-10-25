# Tactical RMM Update (Docker)

> **Anwendungsfall:** Update der Docker-basierten Tactical RMM Installation unter `/opt/trmm` (eingerichtet mit `install.sh`).

## Übersicht

| Komponente | Details |
|------------|---------|
| RMM-VM | Debian/Ubuntu mit Docker, Projekt unter `/opt/trmm` |
| .env Einstellung | `VERSION=<release>` (vom Installer gepinnt, z.B. `1.5.2`) |
| Werkzeug | `trmmctl update` |

## Voraussetzungen

- SSH-Zugang zur RMM-VM
- VM-Snapshot erstellt (Rollback-Möglichkeit)
- SSL-Zertifikat aktuell (siehe [01 – SSL-Zertifikat erneuern](01-ssl-zertifikat-erneuern.md))

---

## Schritt 1: Automatische Agent-Updates deaktivieren

> ⚠️ **WICHTIG:** Vor dem Update unbedingt durchführen!

Neue Agent-Versionen können bei einigen Antivirus-Programmen Fehlalarme auslösen. Daher erst manuell testen.

1. Im Browser Tactical RMM Web-UI öffnen
2. **Settings** → **Global Settings**
3. **"Enable agent automatic self update"** → **Deaktivieren**
4. Speichern

---

## Schritt 2: Update durchführen

```bash
sudo trmmctl update            # neuestes Release von GitHub
sudo trmmctl update 1.5.2      # oder eine bestimmte Version
```

`trmmctl update`:

1. ermittelt das neueste Release (`api.github.com/repos/amidaware/tacticalrmm/releases/latest`)
2. erstellt ein Backup nach `/var/backups/trmm/` (überspringen: `--no-backup`)
3. setzt `VERSION` in `/opt/trmm/.env` und lädt die Images – schlägt der Pull fehl, wird `VERSION` zurückgesetzt
4. erstellt die Container neu (`docker compose up -d`)
5. löscht ungenutzte alte TRMM-Images

> 💡 Steht in der `.env` noch `VERSION=latest`, zieht `trmmctl update` einfach das neueste `latest`. Empfohlen ist eine feste Version – dann ist jederzeit klar, was läuft.

Die Datenbank-Images (`postgres:18-alpine`, `redis:8-alpine`, `mongo:8.0`) bekommen dabei automatisch ihre Patch-Updates innerhalb der Major-Version.

Init beobachten (5-10 Minuten):

```bash
sudo trmmctl logs init
```

---

## Schritt 3: Update verifizieren

```bash
sudo trmmctl status
```

- Alle Container `Up` / `running`
- Im Browser: oben links sollte die neue Version stehen

---

## Schritt 4: Agents testen (optional)

> 💡 **Hinweis:** Falls die Agents bereits auf der aktuellen Version sind, ist dieser Schritt nicht nötig. Prüfe in der Web-UI unter **Agents** die Agent-Version.

Falls Agents noch auf alter Version:

1. In der Web-UI: **Agents** → 2-3 Test-Agents auswählen
2. **Update Agents** klicken
3. Ein paar Minuten warten
4. Prüfen ob neue Agent-Version angezeigt wird
5. Prüfen ob Antivirus Alarm schlägt

### Bei Erfolg:

**Settings** → **Global Settings** → **"Enable agent automatic self update"** → **Aktivieren**

---

## Scripts & Compose-File aktualisieren

Unabhängig vom TRMM-Release kann das Compose-File dieses Repos (z.B. neue Image-Versionen, Healthchecks) aktualisiert werden:

```bash
sudo trmmctl self-update
```

Das führt den Online-Installer erneut aus. `/opt/trmm/.env` bleibt unverändert, eine geänderte `docker-compose.yml` wird vorher als `docker-compose.yml.bak-<datum>` gesichert.

### Major-Version einer Datenbank wechseln

Beispiel PostgreSQL 18 → 19:

```bash
sudo trmmctl backup
sudo sed -i 's/^POSTGRES_VERSION=.*/POSTGRES_VERSION=19/' /opt/trmm/.env
sudo trmmctl migrate-db
```

`migrate-db` startet die alte Version auf dem alten Volume, erstellt einen Dump, importiert ihn in ein neues Volume (`trmm_postgres19_data`) und startet den Stack. Das alte Volume bleibt als Rollback erhalten.

---

## Schnellreferenz - Alle Befehle

```bash
# ============================================
# TRMM Update
# ============================================

# 1. In Web-UI: Automatische Agent-Updates DEAKTIVIEREN!

# 2. Update (inkl. Backup und Image-Cleanup)
sudo trmmctl update

# 3. Status / Init prüfen
sudo trmmctl status
sudo trmmctl logs init

# 4. In Web-UI: Version prüfen
# 5. In Web-UI: Agent-Versionen prüfen (evtl. schon aktuell)
# 6. In Web-UI: Automatische Agent-Updates wieder AKTIVIEREN
```

---

## Troubleshooting

### Update zeigt alte Version

```bash
sudo trmmctl compose pull
sudo trmmctl restart
```

### Container starten nicht

```bash
sudo trmmctl doctor
sudo trmmctl logs            # alle
sudo trmmctl logs backend    # einzelner Dienst
```

### "Volume ... fehlt, es gibt aber ..."

Die Datenbank-Version in der `.env` passt nicht zu den vorhandenen Volumes:

```bash
sudo trmmctl migrate-db
```

### Agent-Update schlägt fehl

1. Antivirus temporär deaktivieren
2. Agent manuell updaten
3. Antivirus-Ausnahme für Tactical Agent hinzufügen
4. Antivirus wieder aktivieren

### Rollback

```bash
# Backup von vor dem Update einspielen (VERSION in .env ggf. zurücksetzen)
ls -lt /var/backups/trmm/
sudo trmmctl restore /var/backups/trmm/trmm-<datum>.tar
```

Falls alles schiefgeht → VM-Snapshot zurückspielen.

---

## Checkliste nach dem Update

- [ ] Neue Version in Web-UI bestätigt
- [ ] Alle Container laufen (`trmmctl status`)
- [ ] Agent-Versionen geprüft
- [ ] Automatische Agent-Updates wieder aktiviert
- [ ] VM-Snapshot kann gelöscht werden (oder behalten)

---

## Weiterführende Links

- [Tactical RMM Dokumentation](https://docs.tacticalrmm.com/)
- [Docker Update Anleitung (offiziell)](https://docs.tacticalrmm.com/update_docker/)
- [GitHub Releases](https://github.com/amidaware/tacticalrmm/releases)
- [GitHub Issues](https://github.com/amidaware/tacticalrmm/issues)
