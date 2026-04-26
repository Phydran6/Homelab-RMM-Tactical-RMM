# Wartung & Updates

Schritt-für-Schritt-Anleitungen für wiederkehrende Wartungsaufgaben rund um Tactical RMM.

| # | Anleitung | Beschreibung |
|---|-----------|--------------|
| 01 | [SSL-Zertifikat erneuern](01-ssl-zertifikat-erneuern.md) | Wildcard-Zertifikat mit Certbot (DNS-Challenge) erneuern und in TRMM & Nginx Proxy Manager eintragen |
| 02 | [TRMM Update](02-trmm-update.md) | Tactical RMM Docker-Installation auf die neueste Version aktualisieren |

## Wann was?

| Aufgabe | Intervall |
|---------|-----------|
| SSL-Zertifikat erneuern | Alle ~60 Tage (Let's Encrypt läuft nach 90 Tagen ab) |
| TRMM updaten | Nach Bedarf / bei neuem Release |
