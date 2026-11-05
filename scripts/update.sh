#!/usr/bin/env bash
# Met à jour toutes les applications vers leur dernière version
# Usage :  ./scripts/update.sh
set -euo pipefail
cd "$(dirname "$0")/.."
DOCKER="docker"; docker info >/dev/null 2>&1 || DOCKER="sudo docker"

echo "⚠ Avant une mise à jour d'Immich, lis les notes de version :"
echo "  https://github.com/immich-app/immich/releases"
read -rp "Continuer ? [o/N] " r
[[ "$r" =~ ^[oOyY]$ ]] || exit 0

$DOCKER compose pull
$DOCKER compose up -d
$DOCKER image prune -f
echo "✅ Mise à jour terminée"
