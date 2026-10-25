# Wartung & Updates

Schritt-für-Schritt-Anleitungen für wiederkehrende Wartungsaufgaben rund um Tactical RMM (Installation unter `/opt/trmm`, Verwaltung mit `trmmctl`).

| # | Anleitung | Beschreibung |
|---|-----------|--------------|
| 01 | [SSL-Zertifikat erneuern](01-ssl-zertifikat-erneuern.md) | Wildcard-Zertifikat mit Certbot (DNS-Challenge) erneuern, mit `trmmctl cert` in TRMM übernehmen und in Nginx Proxy Manager eintragen |
| 02 | [TRMM Update](02-trmm-update.md) | Tactical RMM mit `trmmctl update` auf die neueste Version aktualisieren |

## Wann was?

| Aufgabe | Intervall | Befehl |
|---------|-----------|--------|
| SSL-Zertifikat erneuern | Alle ~60 Tage (Let's Encrypt läuft nach 90 Tagen ab) | `certbot` + `sudo trmmctl cert` |
| TRMM updaten | Nach Bedarf / bei neuem Release | `sudo trmmctl update` |
| Backup | Täglich automatisch (03:15) | `sudo trmmctl backup` |
| Systemcheck | Bei Problemen | `sudo trmmctl doctor` |
