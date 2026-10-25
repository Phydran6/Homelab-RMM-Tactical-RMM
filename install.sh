#!/bin/bash
# ==============================================================================
# install.sh
# Online-Installer: Tactical RMM (Docker) unter /opt/trmm + Update-Scripts
# ==============================================================================
# Autor:    Phydran6
# Version:  2026-10-25
# System:   Debian 12/13, Ubuntu 22.04+ (Stack: nur amd64)
# ==============================================================================
# Online (GitHub raw):
#   curl -fsSL https://raw.githubusercontent.com/Phydran6/Homelab-RMM-Tactical-RMM/main/install.sh | sudo bash
#   curl -fsSL .../install.sh | sudo bash -s -- --domain example.com --yes
#
# Lokal aus einem Clone:
#   sudo ./install.sh [optionen]
#
# Erneut ausfuehren = Update (Scripts + Compose-File, .env bleibt unveraendert)
# ==============================================================================
# Ziel-Layout auf dem Server:
#   /opt/trmm/                         docker-compose.yml, .env (600), .env.example
#   /usr/local/sbin/trmmctl            Verwaltung (update, cert, backup, migrate-db ...)
#   /usr/local/sbin/server-update      unkritische Updates automatisch
#   /usr/local/sbin/apt-smart-update   interaktives Update mit Timeout-Menue
#   /usr/local/sbin/pve-disk-resize    Root-Partition nach Disk-Vergroesserung erweitern
#   /usr/local/bin/update-check        Updates pruefen und kategorisieren
#   /etc/default/trmm                  Einstellungen fuer trmmctl
#   /etc/systemd/system/*.timer        taegliches Backup / Update-Check
#   /etc/logrotate.d/homelab-rmm
#   /var/backups/trmm/                 Backups
# ==============================================================================

set -euo pipefail

REPO="${TRMM_REPO:-Phydran6/Homelab-RMM-Tactical-RMM}"
REF="${TRMM_REF:-main}"

TRMM_DIR=/opt/trmm
ENV_FILE="$TRMM_DIR/.env"
CONFIG_FILE=/etc/default/trmm

# Repo-Pfad : Modus : Gruppe (tools = immer, stack = nur mit TRMM)
FILES=(
    "usr/local/bin/update-check:0755:tools"
    "usr/local/sbin/server-update:0755:tools"
    "usr/local/sbin/apt-smart-update:0755:tools"
    "usr/local/sbin/pve-disk-resize:0755:tools"
    "etc/systemd/system/update-check.service:0644:tools"
    "etc/systemd/system/update-check.timer:0644:tools"
    "etc/logrotate.d/homelab-rmm:0644:tools"
    "usr/local/sbin/trmmctl:0755:stack"
    "etc/default/trmm:0644:stack"
    "etc/systemd/system/trmm-backup.service:0644:stack"
    "etc/systemd/system/trmm-backup.timer:0644:stack"
    "opt/trmm/docker-compose.yml:0644:stack"
    "opt/trmm/.env.example:0644:stack"
)
# Konfigurationsdateien: nur anlegen, nie ueberschreiben
CONFFILES=("etc/default/trmm")
# Alte Pfade (install.sh bis 2026-02) -> Symlinks auf die neuen
COMPAT_LINKS=(
    "/usr/local/bin/update-check.sh:/usr/local/bin/update-check"
    "/usr/local/bin/server-update.sh:/usr/local/sbin/server-update"
)

# Optionen
DOMAIN=""
ADMIN_USER=""
ASSUME_YES=0
TOOLS_ONLY=0
NO_START=0
SKIP_DOCKER=0
UNINSTALL=0
FORCE_REMOTE=0
BACKUP_TIMER=""
UPDATE_TIMER=""

# Laufzeit
SRC_DIR=""
STAGE=""
NEW_ENV=0
NEED_MIGRATE=0
GEN_PASS=""

# Farben
if [[ -t 1 ]]; then
    ROT='\033[0;31m' GRUEN='\033[0;32m' GELB='\033[0;33m' BLAU='\033[0;34m'
    FETT='\033[1m' RESET='\033[0m'
else
    ROT='' GRUEN='' GELB='' BLAU='' FETT='' RESET=''
fi

# ------------------------------------------------------------------------------
# Hilfsfunktionen
# ------------------------------------------------------------------------------
info()   { echo -e "${BLAU}=>${RESET} $*"; }
ok()     { echo -e "${GRUEN}✓${RESET} $*"; }
warn()   { echo -e "${GELB}!${RESET} $*" >&2; }
die()    { echo -e "${ROT}✗ $*${RESET}" >&2; exit 1; }
header() { echo ""; echo -e "${FETT}=== $* ===${RESET}"; }

# Eingabe ueber /dev/tty (bei "curl | bash" ist stdin das Script selbst)
# Usage: ask VAR "Frage" "default"
ask() {
    local __var=$1 frage=$2 default=${3:-} antwort=""
    if [[ $ASSUME_YES -eq 0 && -r /dev/tty ]]; then
        read -r -p "$frage${default:+ [$default]}: " antwort </dev/tty || true
    fi
    printf -v "$__var" '%s' "${antwort:-$default}"
}

# Usage: ask_yn "Frage" j|n  -> Rueckgabe 0 = ja
ask_yn() {
    local frage=$1 default=$2 antwort=""
    if [[ $ASSUME_YES -eq 0 && -r /dev/tty ]]; then
        read -r -p "$frage [$([[ $default == j ]] && echo J/n || echo j/N)] " antwort </dev/tty || true
    fi
    antwort=${antwort:-$default}
    [[ $antwort =~ ^[JjYy]$ ]]
}

# Wert in einer env-Datei setzen oder anhaengen (awk statt sed wegen Sonderzeichen)
env_set() {
    local file=$1 tmp
    tmp=$(mktemp "$file.XXXXXX")
    KEY=$2 VAL=$3 awk '
        BEGIN { k = ENVIRON["KEY"]; v = ENVIRON["VAL"]; done = 0 }
        index($0, k "=") == 1 { if (!done) { print k "=" v; done = 1 }; next }
        { print }
        END { if (!done) print k "=" v }
    ' "$file" >"$tmp"
    chmod --reference="$file" "$tmp"
    mv "$tmp" "$file"
}

env_has() {
    grep -q "^$2=" "$1"
}

env_get() {
    sed -n "s/^$2=//p" "$1" | tail -n 1
}

rand_pass() {
    openssl rand -hex 20
}

latest_trmm_release() {
    curl -fsSL https://api.github.com/repos/amidaware/tacticalrmm/releases/latest 2>/dev/null \
        | sed -n 's/.*"tag_name": *"v\{0,1\}\([^"]*\)".*/\1/p' | head -n 1 || true
}

cpu_has_avx() {
    grep -qw avx /proc/cpuinfo 2>/dev/null
}

usage() {
    cat <<EOF
Homelab RMM Installer - Tactical RMM (Docker) unter $TRMM_DIR + Update-Scripts

Verwendung:
  curl -fsSL https://raw.githubusercontent.com/$REPO/$REF/install.sh | sudo bash -s -- [optionen]
  sudo ./install.sh [optionen]

Optionen:
  --domain DOMAIN        Basis-Domain (rmm./api./mesh.DOMAIN)
  --admin NAME           TRMM-Admin-Benutzer (Default: admin)
  -y, --yes              keine Rueckfragen, Defaults verwenden
  --tools-only           nur Update-Scripts installieren (kein Docker/TRMM)
  --no-start             Stack einrichten, aber nicht starten
  --skip-docker          Docker-Installation ueberspringen
  --backup-timer | --no-backup-timer       taegliches Backup (Default: an)
  --update-timer | --no-update-timer       taeglicher update-check (Default: aus)
  --ref REF              Branch/Tag fuer den Download (Default: $REF)
  --remote               auch im Clone aus GitHub laden
  --uninstall            Scripts/Timer entfernen (Daten in $TRMM_DIR bleiben)
  -h, --help             diese Hilfe
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)          DOMAIN=${2:?--domain braucht einen Wert}; shift ;;
            --admin)           ADMIN_USER=${2:?--admin braucht einen Wert}; shift ;;
            -y|--yes)          ASSUME_YES=1 ;;
            --tools-only)      TOOLS_ONLY=1 ;;
            --no-start)        NO_START=1 ;;
            --skip-docker)     SKIP_DOCKER=1 ;;
            --backup-timer)    BACKUP_TIMER=1 ;;
            --no-backup-timer) BACKUP_TIMER=0 ;;
            --update-timer)    UPDATE_TIMER=1 ;;
            --no-update-timer) UPDATE_TIMER=0 ;;
            --ref)             REF=${2:?--ref braucht einen Wert}; shift ;;
            --remote)          FORCE_REMOTE=1 ;;
            --uninstall)       UNINSTALL=1 ;;
            -h|--help)         usage; exit 0 ;;
            *)                 die "Unbekannte Option: $1 (siehe --help)" ;;
        esac
        shift
    done
    DOMAIN=${DOMAIN#*://}
    DOMAIN=${DOMAIN%%/*}
}

# ------------------------------------------------------------------------------
# Pruefungen
# ------------------------------------------------------------------------------
check_system() {
    header "System-Check"
    [[ $EUID -eq 0 ]] || die "Bitte als root ausfuehren (curl ... | sudo bash)"

    [[ -r /etc/os-release ]] || die "/etc/os-release fehlt"
    # shellcheck source=/dev/null
    . /etc/os-release
    if [[ ${ID:-} != debian && ${ID:-} != ubuntu && ${ID_LIKE:-} != *debian* ]]; then
        die "Nur Debian/Ubuntu werden unterstuetzt (gefunden: ${PRETTY_NAME:-unbekannt})"
    fi
    ok "${PRETTY_NAME:-$ID}"

    command -v systemctl >/dev/null 2>&1 || die "systemd wird benoetigt"

    if [[ $TOOLS_ONLY -eq 0 ]]; then
        local arch
        arch=$(dpkg --print-architecture)
        [[ $arch == amd64 ]] || die "Tactical-RMM-Images gibt es nur fuer amd64 (hier: $arch) - nur Scripts: --tools-only"

        local mem
        mem=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
        if (( mem < 3800 )); then
            warn "Nur ${mem} MB RAM - fuer TRMM werden mindestens 4 GB empfohlen"
        else
            ok "RAM ${mem} MB"
        fi

        # MongoDB >= 5.0 startet ohne AVX nicht ("Illegal instruction") - vor jeder Aenderung abbrechen
        if cpu_has_avx; then
            ok "CPU mit AVX (MongoDB 8.0 moeglich)"
        else
            die "CPU ohne AVX - MongoDB 8.0 laeuft so nicht. Es wurde nichts veraendert.
  Proxmox: VM herunterfahren -> Hardware -> Prozessor -> Typ 'host' oder 'x86-64-v3'
  -> VM starten, Installer erneut ausfuehren. Pruefen: grep -cw avx /proc/cpuinfo"
        fi
    fi

    # Systemzeit muss stimmen, sonst scheitern apt und TLS
    if [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) != "yes" ]]; then
        info "Systemzeit nicht synchron - aktiviere NTP ..."
        timedatectl set-ntp true 2>/dev/null || true
        for _ in $(seq 1 15); do
            [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == "yes" ]] && break
            sleep 2
        done
        if [[ $(timedatectl show -p NTPSynchronized --value 2>/dev/null) == "yes" ]]; then
            ok "Systemzeit synchron"
        else
            warn "Systemzeit weiterhin nicht synchron ($(date)) - bitte pruefen"
        fi
    else
        ok "Systemzeit synchron"
    fi

    # Pi-hole & Co. beantworten geblockte Domains mit 0.0.0.0 / 127.0.0.1
    local h ip
    for h in raw.githubusercontent.com download.docker.com registry-1.docker.io auth.docker.io; do
        ip=$(getent ahostsv4 "$h" 2>/dev/null | awk 'NR==1 {print $1}')
        if [[ -z $ip || $ip == 0.0.0.0 || $ip == 127.* ]]; then
            warn "DNS: $h -> ${ip:-nicht aufloesbar} (Pi-hole Whitelist pruefen, siehe docs/)"
        fi
    done
}

# ------------------------------------------------------------------------------
# Dateien holen (lokaler Clone oder GitHub raw)
# ------------------------------------------------------------------------------
detect_source() {
    local self=${BASH_SOURCE[0]:-} d
    if [[ $FORCE_REMOTE -eq 0 && -n $self && -f $self ]]; then
        d=$(cd "$(dirname "$self")" && pwd)
        [[ -f $d/opt/trmm/docker-compose.yml ]] && SRC_DIR=$d
    fi
    return 0
}

wanted() {
    local group=$1
    [[ $group == tools || $TOOLS_ONLY -eq 0 ]]
}

fetch_files() {
    header "Dateien laden"
    STAGE=$(mktemp -d)
    trap 'rm -rf "$STAGE"' EXIT

    if [[ -n $SRC_DIR ]]; then
        info "Quelle: lokaler Clone $SRC_DIR"
    else
        info "Quelle: https://raw.githubusercontent.com/$REPO/$REF"
    fi

    local entry path group
    for entry in "${FILES[@]}"; do
        IFS=: read -r path _ group <<<"$entry"
        wanted "$group" || continue
        mkdir -p "$STAGE/$(dirname "$path")"
        if [[ -n $SRC_DIR ]]; then
            cp "$SRC_DIR/$path" "$STAGE/$path"
        else
            curl -fsSL --retry 3 --retry-delay 2 "https://raw.githubusercontent.com/$REPO/$REF/$path" -o "$STAGE/$path" \
                || die "Download fehlgeschlagen: $path"
        fi
        [[ -s $STAGE/$path ]] || die "Leere Datei: $path"
        # schuetzt vor HTML-Fehlerseiten (Proxy, Pi-hole Blockseite)
        if [[ $path == usr/local/* ]] && ! head -n 1 "$STAGE/$path" | grep -q '^#!/bin/bash'; then
            die "Ungueltiger Inhalt (kein Bash-Script): $path"
        fi
    done
    ok "Alle Dateien geladen"
}

install_files() {
    header "Installation nach Linux-Standardpfaden"
    local entry path mode group dest c is_conf
    for entry in "${FILES[@]}"; do
        IFS=: read -r path mode group <<<"$entry"
        wanted "$group" || continue
        dest="/$path"

        is_conf=0
        for c in "${CONFFILES[@]}"; do [[ $c == "$path" ]] && is_conf=1; done
        if [[ $is_conf -eq 1 && -e $dest ]]; then
            ok "$dest (vorhanden, unveraendert)"
            continue
        fi

        # verwaltete Compose-Datei: lokale Aenderungen sichern
        if [[ $path == opt/trmm/docker-compose.yml && -f $dest ]] && ! cmp -s "$STAGE/$path" "$dest"; then
            cp -p "$dest" "$dest.bak-$(date +%Y%m%d-%H%M%S)"
            info "Alte Compose-Datei gesichert ($dest.bak-*)"
        fi

        install -D -m "$mode" "$STAGE/$path" "$dest"
        ok "$dest"

        if [[ $path == etc/default/trmm ]]; then
            env_set "$dest" TRMM_REPO "$REPO"
            env_set "$dest" TRMM_REF "$REF"
        fi
    done

    local link from to
    for link in "${COMPAT_LINKS[@]}"; do
        IFS=: read -r from to <<<"$link"
        [[ -e $to ]] || continue
        ln -sfn "$to" "$from"
    done
    ok "Kompatibilitaets-Links fuer alte *.sh-Pfade"

    install -d -m 700 /var/backups/trmm
    systemctl daemon-reload 2>/dev/null || warn "systemd laeuft nicht (Container?) - Timer werden uebersprungen"
}

# ------------------------------------------------------------------------------
# Docker
# ------------------------------------------------------------------------------
install_docker() {
    header "Docker"
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?'), Compose $(docker compose version --short)"
        systemctl enable --now docker >/dev/null 2>&1 || true
        return 0
    fi

    if command -v docker >/dev/null 2>&1; then
        # z.B. Debian-Paket docker.io ohne Compose v2 -> Plugin wie bisher manuell
        info "Docker vorhanden, Compose v2 fehlt - installiere Plugin ..."
        install -d /usr/local/lib/docker/cli-plugins
        curl -fsSL --retry 3 https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
            -o /usr/local/lib/docker/cli-plugins/docker-compose
        chmod 755 /usr/local/lib/docker/cli-plugins/docker-compose
        docker compose version >/dev/null 2>&1 || die "Compose-Plugin funktioniert nicht"
        ok "Compose $(docker compose version --short)"
        return 0
    fi

    # offizielles Docker-Repository (Engine + Compose-Plugin, aktuelle Versionen)
    # shellcheck source=/dev/null
    . /etc/os-release
    local dist=$ID codename=${VERSION_CODENAME:-}
    [[ $ID == ubuntu ]] && codename=${UBUNTU_CODENAME:-$codename}
    [[ $ID != debian && $ID != ubuntu ]] && dist=debian
    [[ -n $codename ]] || die "Distribution-Codename nicht ermittelbar"

    info "Installiere Docker Engine aus download.docker.com ($dist $codename) ..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL "https://download.docker.com/linux/$dist/gpg" -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    cat >/etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/$dist
Suites: $codename
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    systemctl enable --now docker >/dev/null
    ok "Docker $(docker version --format '{{.Server.Version}}'), Compose $(docker compose version --short)"
}

# ------------------------------------------------------------------------------
# Alte Installation (~/trmm, ~/tactical-rmm) uebernehmen
# ------------------------------------------------------------------------------
migrate_legacy() {
    local dir="" project="" d
    command -v docker >/dev/null 2>&1 || return 0

    # 1. laufender Stack verraet Verzeichnis und Projektnamen
    if docker inspect trmm-backend >/dev/null 2>&1; then
        dir=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}' trmm-backend 2>/dev/null || true)
        project=$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' trmm-backend 2>/dev/null || true)
        [[ $dir == "$TRMM_DIR" ]] && return 0
    fi
    # 2. sonst bekannte Verzeichnisse
    if [[ -z $dir ]]; then
        for d in /root/trmm /root/tactical-rmm /home/*/trmm /home/*/tactical-rmm; do
            if [[ -f $d/.env && -f $d/docker-compose.yml ]]; then
                dir=$d
                project=$(basename "$d" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
                break
            fi
        done
    fi
    [[ -n $dir && -n $project ]] || return 0

    header "Bestehende Installation gefunden"
    echo "  Verzeichnis: $dir"
    echo "  Projekt:     $project"
    echo "  -> wird nach $TRMM_DIR uebernommen; Daten-Volumes bleiben erhalten,"
    echo "     PostgreSQL 13 / MongoDB 4.4 werden per Dump in die neuen Versionen migriert."
    if [[ -f $ENV_FILE ]]; then
        warn "$ENV_FILE existiert bereits - alte Installation wird nur gestoppt"
    fi
    ask_yn "Uebernehmen?" j || die "Abbruch - der alte Stack belegt dieselben Containernamen (trmm-*)"
    [[ -f $dir/.env ]] || die "$dir/.env fehlt - bitte manuell nach $ENV_FILE kopieren"

    if [[ ! -f $ENV_FILE ]]; then
        install -d -m 755 "$TRMM_DIR"
        install -m 600 "$dir/.env" "$ENV_FILE"
        env_set "$ENV_FILE" COMPOSE_PROJECT_NAME "$project"
        ok ".env uebernommen (COMPOSE_PROJECT_NAME=$project)"
    fi

    info "Alten Stack stoppen ..."
    if [[ -f $dir/docker-compose.yml ]]; then
        (cd "$dir" && docker compose down)
        # verhindert versehentlichen Start des alten Stacks auf den alten Volumes
        mv "$dir/docker-compose.yml" "$dir/docker-compose.yml.migrated-to-opt-trmm"
        ok "Alter Stack gestoppt, $dir/docker-compose.yml umbenannt"
    else
        docker compose -p "$project" down
        ok "Alter Stack gestoppt"
    fi
    NEED_MIGRATE=1
}

# ------------------------------------------------------------------------------
# .env erzeugen / ergaenzen
# ------------------------------------------------------------------------------
setup_env() {
    header "Konfiguration $ENV_FILE"
    local mongo_default=8.0

    if [[ ! -f $ENV_FILE ]]; then
        NEW_ENV=1
        if [[ -z $DOMAIN ]]; then
            ask DOMAIN "Basis-Domain (ergibt rmm./api./mesh.<domain>)" ""
        fi
        [[ -n $DOMAIN ]] || die "Domain fehlt (--domain example.com)"
        [[ -n $ADMIN_USER ]] || ask ADMIN_USER "TRMM-Admin-Benutzer" "admin"

        local version
        version=$(latest_trmm_release)
        version=${version:-latest}
        GEN_PASS=$(rand_pass)

        install -m 600 "$TRMM_DIR/.env.example" "$ENV_FILE"
        env_set "$ENV_FILE" VERSION "$version"
        env_set "$ENV_FILE" MONGO_VERSION "$mongo_default"
        env_set "$ENV_FILE" TRMM_USER "$ADMIN_USER"
        env_set "$ENV_FILE" TRMM_PASS "$GEN_PASS"
        env_set "$ENV_FILE" APP_HOST "rmm.$DOMAIN"
        env_set "$ENV_FILE" API_HOST "api.$DOMAIN"
        env_set "$ENV_FILE" MESH_HOST "mesh.$DOMAIN"
        env_set "$ENV_FILE" MESH_USER "meshadmin"
        env_set "$ENV_FILE" MESH_PASS "$(rand_pass)"
        env_set "$ENV_FILE" MONGODB_USER "mongouser"
        env_set "$ENV_FILE" MONGODB_PASSWORD "$(rand_pass)"
        env_set "$ENV_FILE" POSTGRES_USER "trmm"
        env_set "$ENV_FILE" POSTGRES_PASS "$(rand_pass)"
        ok "Neue .env mit zufaelligen Passwoertern (TRMM $version, MongoDB $mongo_default)"
    else
        # bestehende/uebernommene .env nur um fehlende Schluessel ergaenzen
        local kv key val added=""
        for kv in "COMPOSE_PROJECT_NAME=trmm" "POSTGRES_VERSION=18" "REDIS_VERSION=8" \
                  "MONGO_VERSION=$mongo_default" "MONGO_CACHE_GB=0.25"; do
            key=${kv%%=*}; val=${kv#*=}
            if ! env_has "$ENV_FILE" "$key"; then
                env_set "$ENV_FILE" "$key" "$val"
                added+=" $key"
            fi
        done
        chmod 600 "$ENV_FILE"
        if [[ -n $added ]]; then ok "Ergaenzt:$added"; else ok "Vorhanden, unveraendert"; fi
        local api
        api=$(env_get "$ENV_FILE" API_HOST)
        DOMAIN=${DOMAIN:-${api#*.}}
    fi

    # Domain fuer "trmmctl cert" merken
    if [[ -n $DOMAIN ]] && [[ -z $(env_get "$CONFIG_FILE" CERT_DOMAIN) ]]; then
        env_set "$CONFIG_FILE" CERT_DOMAIN "$DOMAIN"
    fi

    # vorhandenes Let's-Encrypt-Zertifikat direkt uebernehmen
    if [[ $NEW_ENV -eq 1 && -r /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]]; then
        /usr/local/sbin/trmmctl cert "$DOMAIN" --no-restart
    fi
}

# ------------------------------------------------------------------------------
# Timer
# ------------------------------------------------------------------------------
setup_timers() {
    header "Automatisierung (systemd-Timer)"
    # --yes auf bestehender Installation (z.B. trmmctl self-update): Zustand beibehalten
    local keep=0
    [[ $ASSUME_YES -eq 1 && $NEW_ENV -eq 0 ]] && keep=1

    if [[ $TOOLS_ONLY -eq 0 ]]; then
        if [[ -z $BACKUP_TIMER ]]; then
            if systemctl is-enabled -q trmm-backup.timer 2>/dev/null; then BACKUP_TIMER=1
            elif [[ $keep -eq 1 ]]; then BACKUP_TIMER=0
            elif ask_yn "Taegliches Backup nach /var/backups/trmm (03:15)?" j; then BACKUP_TIMER=1
            else BACKUP_TIMER=0; fi
        fi
        if [[ $BACKUP_TIMER -eq 1 ]]; then
            systemctl enable --now trmm-backup.timer >/dev/null 2>&1
            ok "trmm-backup.timer aktiv"
        else
            systemctl disable --now trmm-backup.timer >/dev/null 2>&1 || true
            info "trmm-backup.timer aus"
        fi
    fi

    if [[ -z $UPDATE_TIMER ]]; then
        if systemctl is-enabled -q update-check.timer 2>/dev/null; then UPDATE_TIMER=1
        elif [[ $keep -eq 1 ]]; then UPDATE_TIMER=0
        elif ask_yn "Taeglichen update-check (02:00, Ausgabe im Journal)?" n; then UPDATE_TIMER=1
        else UPDATE_TIMER=0; fi
    fi
    if [[ $UPDATE_TIMER -eq 1 ]]; then
        systemctl enable --now update-check.timer >/dev/null 2>&1
        ok "update-check.timer aktiv (journalctl -u update-check)"
        # alten Cron-Job des frueheren Installers entfernen
        if crontab -l 2>/dev/null | grep -q 'update-check.sh'; then
            crontab -l 2>/dev/null | grep -v 'update-check.sh' | crontab -
            ok "Alter Cron-Job fuer update-check.sh entfernt"
        fi
    else
        systemctl disable --now update-check.timer >/dev/null 2>&1 || true
        info "update-check.timer aus"
    fi
}

# ------------------------------------------------------------------------------
# Start
# ------------------------------------------------------------------------------
start_stack() {
    header "Tactical RMM starten"
    if [[ $NO_START -eq 1 ]]; then
        info "--no-start: spaeter starten mit 'trmmctl up'"
        return 0
    fi
    info "Images laden (kann einige Minuten dauern) ..."
    /usr/local/sbin/trmmctl pull
    if [[ $NEED_MIGRATE -eq 1 ]]; then
        /usr/local/sbin/trmmctl --yes migrate-db
    else
        /usr/local/sbin/trmmctl up
    fi
}

summary() {
    header "Fertig"
    echo "Befehle:"
    echo "  update-check                  Updates pruefen"
    echo "  sudo server-update            unkritische Updates installieren"
    echo "  sudo apt-smart-update         interaktives Update (Timeout-Menue)"
    echo "  sudo pve-disk-resize          Root-Partition nach Disk-Vergroesserung erweitern"
    [[ $TOOLS_ONLY -eq 1 ]] && return 0

    echo "  sudo trmmctl status|logs|update|cert|backup|doctor|help"
    echo ""
    echo "Tactical RMM:"
    echo "  Projekt:   $TRMM_DIR (Konfiguration: $ENV_FILE)"
    echo "  Web-UI:    https://$(env_get "$ENV_FILE" APP_HOST)"
    echo "  API:       https://$(env_get "$ENV_FILE" API_HOST)"
    echo "  Mesh:      https://$(env_get "$ENV_FILE" MESH_HOST)"
    if [[ $NEW_ENV -eq 1 ]]; then
        echo ""
        echo -e "  Login:     ${FETT}$(env_get "$ENV_FILE" TRMM_USER)${RESET} / ${FETT}$GEN_PASS${RESET}"
        echo "             (steht auch in $ENV_FILE - nach dem ersten Login 2FA einrichten)"
    fi
    echo ""
    echo "Hinweise:"
    echo "  - DNS A-Records rmm/api/mesh muessen auf diesen Server bzw. den Reverse Proxy zeigen"
    echo "  - Erster Start dauert 5-10 Minuten:  sudo trmmctl logs init"
    if [[ -z $(env_get "$ENV_FILE" CERT_PUB_KEY) ]]; then
        echo "  - Noch selbstsigniertes Zertifikat:  certbot (wartung/01) + sudo trmmctl cert"
    fi
}

# ------------------------------------------------------------------------------
# Deinstallation (Daten bleiben)
# ------------------------------------------------------------------------------
uninstall() {
    [[ $EUID -eq 0 ]] || die "Bitte als root ausfuehren"
    header "Deinstallation"
    systemctl disable --now trmm-backup.timer update-check.timer >/dev/null 2>&1 || true
    local entry path link from
    for entry in "${FILES[@]}"; do
        IFS=: read -r path _ _ <<<"$entry"
        case $path in
            opt/trmm/*|etc/default/*) continue ;;
        esac
        rm -f "/$path" && ok "entfernt /$path"
    done
    for link in "${COMPAT_LINKS[@]}"; do
        IFS=: read -r from _ <<<"$link"
        [[ -L $from ]] && rm -f "$from"
    done
    systemctl daemon-reload 2>/dev/null || true
    echo ""
    echo "Nicht entfernt: $TRMM_DIR, $CONFIG_FILE, /var/backups/trmm, Docker-Volumes."
    echo "TRMM komplett entfernen:"
    echo "  cd $TRMM_DIR && docker compose down -v && rm -rf $TRMM_DIR $CONFIG_FILE"
}

# ------------------------------------------------------------------------------
# Main - ganz am Ende, damit ein abgebrochener Download nichts ausfuehrt
# ------------------------------------------------------------------------------
main() {
    parse_args "$@"
    [[ $UNINSTALL -eq 1 ]] && { uninstall; exit 0; }

    echo -e "${FETT}Homelab RMM - Installation${RESET} ($REPO@$REF)"
    check_system

    header "Basis-Pakete"
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl openssl >/dev/null
    ok "ca-certificates curl openssl"

    detect_source
    fetch_files

    if [[ $TOOLS_ONLY -eq 0 ]]; then
        [[ $SKIP_DOCKER -eq 1 ]] || install_docker
        command -v docker >/dev/null 2>&1 || die "Docker fehlt (--skip-docker gesetzt?)"
        install_files
        migrate_legacy
        setup_env
        setup_timers
        start_stack
    else
        install_files
        setup_timers
    fi
    summary
}

main "$@"
