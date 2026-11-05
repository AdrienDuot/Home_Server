#!/usr/bin/env bash
# =====================================================================
#  Installation du serveur maison
#  Usage (depuis le dossier du dépôt) :   ./scripts/install.sh
# =====================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

vert()  { printf '\033[32m%s\033[0m\n' "$*"; }
jaune() { printf '\033[33m%s\033[0m\n' "$*"; }
rouge() { printf '\033[31m%s\033[0m\n' "$*"; }

# --- 1. Vérifier Docker ----------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  rouge "Docker n'est pas installé. Voir https://docs.docker.com/engine/install/ubuntu/"
  exit 1
fi
DOCKER="docker"
if ! docker info >/dev/null 2>&1; then
  jaune "Ton utilisateur n'est pas dans le groupe docker : utilisation de sudo."
  DOCKER="sudo docker"
fi
if ! $DOCKER compose version >/dev/null 2>&1; then
  rouge "Docker Compose (plugin 'docker compose') est introuvable."
  exit 1
fi

# --- 2. Créer le fichier .env ------------------------------------------
genpass() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c "${1:-32}"; }
setenv()  { sed -i "s|^$1=.*|$1=$2|" .env; }

if [ ! -f .env ]; then
  vert "Création du fichier .env…"
  cp .env.example .env

  USER_NAME="${SUDO_USER:-$USER}"
  IP="$(hostname -I | awk '{print $1}')"
  ZONE="$(timedatectl show -p Timezone --value 2>/dev/null || echo Europe/Paris)"

  setenv SERVER_IP "$IP"
  setenv TZ "$ZONE"
  setenv PUID "$(id -u "$USER_NAME")"
  setenv PGID "$(id -g "$USER_NAME")"
  setenv IMMICH_DB_PASSWORD "$(genpass 32)"
  setenv HOMEPAGE_ALLOWED_HOSTS "$IP:3000,localhost:3000"

  jaune "→ .env créé avec l'IP $IP et le fuseau $ZONE."
  jaune "  Vérifie les chemins (APPDATA, PHOTOS_LOCATION, MEDIA_LOCATION) :"
  jaune "  nano .env   puis relance ce script."
  exit 0
fi

# shellcheck disable=SC1091
set -a; source .env; set +a

# --- 3. Créer les dossiers et régler les droits -----------------------
vert "Création des dossiers…"
sudo mkdir -p \
  "$APPDATA"/immich/postgres \
  "$APPDATA"/jellyfin/config "$APPDATA"/jellyfin/cache \
  "$APPDATA"/seerr \
  "$APPDATA"/vaultwarden \
  "$APPDATA"/uptime-kuma \
  "$PHOTOS_LOCATION" \
  "$MEDIA_LOCATION"/films "$MEDIA_LOCATION"/series

sudo chown -R "$PUID:$PGID" "$APPDATA"/jellyfin "$MEDIA_LOCATION" homepage/config
sudo chown -R 1000:1000 "$APPDATA"/seerr   # Seerr tourne toujours avec l'UID 1000

# --- 4. Télécharger et démarrer ---------------------------------------
vert "Téléchargement des images (peut prendre plusieurs minutes)…"
$DOCKER compose pull
vert "Démarrage des services…"
$DOCKER compose up -d

# --- 5. Récapitulatif ------------------------------------------------
echo
vert "✅ Installation terminée ! Ouvre ces adresses dans ton navigateur :"
cat <<EOF

  Homepage     http://$SERVER_IP:3000   ← page d'accueil
  Immich       http://$SERVER_IP:2283   ← photos
  Jellyfin     http://$SERVER_IP:8096   ← films & séries
  Seerr        http://$SERVER_IP:5055   ← demandes de films
  Uptime Kuma  http://$SERVER_IP:3001   ← surveillance
  Vaultwarden  http://$SERVER_IP:8222   ← mots de passe (HTTPS requis, voir README)

Suis la section « Première configuration » du README pour chaque appli.
EOF
