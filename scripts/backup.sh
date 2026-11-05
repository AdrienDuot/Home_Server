#!/usr/bin/env bash
# =====================================================================
#  Sauvegarde du serveur maison
#  Usage :   ./scripts/backup.sh /chemin/vers/disque/externe
#
#  Sauvegarde :
#   - la base de données Immich (export SQL)
#   - les photos Immich (copie incrémentale avec rsync)
#   - les configurations : Vaultwarden, Jellyfin, Seerr, Uptime Kuma, Homepage
#   - le fichier .env
#  Les films/séries ne sont PAS copiés (trop gros, et tu les as sûrement ailleurs).
#
#  Automatiser (tous les jours à 3h) :  sudo crontab -e  puis ajouter :
#   0 3 * * * /chemin/vers/home_server/scripts/backup.sh /mnt/sauvegarde >> /var/log/homeserver-backup.log 2>&1
# =====================================================================
set -euo pipefail

cd "$(dirname "$0")/.."
DEST="${1:?Indique le dossier de destination, ex : ./scripts/backup.sh /mnt/sauvegarde}"

set -a; source .env; set +a
DATE="$(date +%Y-%m-%d_%H%M)"
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

mkdir -p "$DEST"/configs "$DEST"/immich-db "$DEST"/photos
echo "[$DATE] Début de la sauvegarde vers $DEST"

# 1. Base de données Immich
$DOCKER exec immich_postgres pg_dumpall --clean --if-exists --username="$IMMICH_DB_USERNAME" \
  | gzip > "$DEST/immich-db/immich-$DATE.sql.gz"

# 2. Photos Immich (seules les nouveautés sont copiées)
sudo rsync -a --delete \
  --exclude 'thumbs/' --exclude 'encoded-video/' \
  "$PHOTOS_LOCATION"/ "$DEST"/photos/

# 3. Configurations (arrêt rapide pour avoir des fichiers cohérents)
$DOCKER compose stop vaultwarden uptime-kuma seerr jellyfin
sudo tar -czf "$DEST/configs/configs-$DATE.tar.gz" \
  --exclude='jellyfin/cache' --exclude='immich/postgres' \
  -C "$APPDATA" . \
  -C "$PWD" .env homepage/config
$DOCKER compose start vaultwarden uptime-kuma seerr jellyfin

# 4. Garder seulement les 14 dernières sauvegardes
ls -1t "$DEST"/immich-db/*.sql.gz   2>/dev/null | tail -n +15 | xargs -r rm -f
ls -1t "$DEST"/configs/*.tar.gz     2>/dev/null | tail -n +15 | xargs -r rm -f

echo "[$(date +%Y-%m-%d_%H%M)] Sauvegarde terminée ✅"
