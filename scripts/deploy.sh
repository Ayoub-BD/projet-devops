#!/usr/bin/env bash
# Déploie une nouvelle version de l'appli sur le serveur.
# Usage : deploy.sh <image>
set -euo pipefail

IMAGE="$1"

echo "==> Téléchargement de $IMAGE"
docker pull "$IMAGE"

echo "==> Remplacement du conteneur"
docker rm -f app 2>/dev/null || true
docker run -d --name app -p 80:5000 --restart unless-stopped "$IMAGE"

echo "==> Vérification que le site répond"
sleep 3
curl -fsS http://localhost > /dev/null

echo "==> Nettoyage des anciennes images"
docker image prune -f

echo "==> Déploiement réussi"