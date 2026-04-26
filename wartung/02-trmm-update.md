# Tactical RMM Update (Docker)

> **Anwendungsfall:** Update einer Docker-basierten Tactical RMM Installation mit `VERSION=latest` in der .env Datei.

## Übersicht

| Komponente | Details |
|------------|---------|
| RMM-VM | Debian/Ubuntu mit Docker, Verzeichnis `~/trmm` |
| .env Einstellung | `VERSION=latest` |

## Voraussetzungen

- SSH-Zugang zur RMM-VM
- VM-Snapshot erstellt (Rollback-Möglichkeit)
- SSL-Zertifikat aktuell (siehe separate Anleitung)

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

> 💡 **Hinweis:** Da `VERSION=latest` in der `.env` gesetzt ist, reicht es die neuen Images zu pullen. Die `docker-compose.yml` muss nicht geändert werden.

```bash
cd ~/trmm

# Neue Images holen (VERSION=latest zieht automatisch neueste Version)
sudo docker compose pull

# Container neu starten mit neuen Images
sudo docker compose down
sudo docker compose up -d

# Status prüfen - alle Container sollten "Up" oder "running" zeigen
sudo docker compose ps
```

---

## Schritt 3: Alte Images aufräumen

Nach dem Update bleiben alte Images auf der Festplatte. Diese können gelöscht werden:

```bash
# Zeigt ungenutzte Images an
sudo docker images

# Alle ungenutzten Images löschen
sudo docker image prune -a

# Bestätigen mit 'y'
```

Alternativ nur bestimmte Images löschen:

```bash
# Bestimmtes Image löschen (Image-ID aus 'docker images' kopieren)
sudo docker rmi <IMAGE_ID>

# Mehrere auf einmal
sudo docker rmi <IMAGE_ID_1> <IMAGE_ID_2> <IMAGE_ID_3>
```

Komplettes Docker-Cleanup (Images, Container, Volumes, Networks):

```bash
# VORSICHT: Löscht alles Ungenutzte!
sudo docker system prune -a
```

---

## Schritt 4: Update verifizieren

### 4.1 Web-UI prüfen

1. Im Browser Tactical RMM Web-UI öffnen
2. Oben links sollte die neue Version stehen

### 4.2 Container-Status prüfen

```bash
sudo docker compose ps
```

Alle Container sollten `Up` oder `running` zeigen.

---

## Schritt 5: Agents testen (optional)

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

## Schnellreferenz - Alle Befehle

```bash
# ============================================
# TRMM Update
# ============================================

# 1. In Web-UI: Automatische Agent-Updates DEAKTIVIEREN!

# 2. Update durchführen
cd ~/trmm
sudo docker compose pull
sudo docker compose down
sudo docker compose up -d

# 3. Status prüfen
sudo docker compose ps

# 4. Alte Images aufräumen
sudo docker image prune -a

# 5. In Web-UI: Version prüfen
# 6. In Web-UI: Agent-Versionen prüfen (evtl. schon aktuell)
# 7. In Web-UI: Automatische Agent-Updates wieder AKTIVIEREN
```

---

## Troubleshooting

### Update zeigt alte Version

```bash
# Images wurden nicht neu gezogen. Nochmal pullen:
sudo docker compose pull
sudo docker compose down
sudo docker compose up -d
```

### Container starten nicht

```bash
# Logs prüfen
sudo docker compose logs

# Einzelnen Container prüfen (z.B. backend)
sudo docker compose logs tactical-backend
```

### Agent-Update schlägt fehl

1. Antivirus temporär deaktivieren
2. Agent manuell updaten
3. Antivirus-Ausnahme für Tactical Agent hinzufügen
4. Antivirus wieder aktivieren

### Rollback

Falls alles schiefgeht → VM-Snapshot zurückspielen.

---

## Checkliste nach dem Update

- [ ] Neue Version in Web-UI bestätigt
- [ ] Alle Container laufen
- [ ] Agent-Versionen geprüft
- [ ] Automatische Agent-Updates wieder aktiviert
- [ ] VM-Snapshot kann gelöscht werden (oder behalten)
- [ ] Alte Docker Images aufgeräumt

---

## Weiterführende Links

- [Tactical RMM Dokumentation](https://docs.tacticalrmm.com/)
- [Docker Update Anleitung (offiziell)](https://docs.tacticalrmm.com/update_docker/)
- [GitHub Releases](https://github.com/amidaware/tacticalrmm/releases)
- [GitHub Issues](https://github.com/amidaware/tacticalrmm/issues)
