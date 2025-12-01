#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="advance-deeplearning-setup"
TAG="torch2.8-cuda12.8"
REMOTE_IMAGE="almamoha/advance-deeplearning:${TAG}"

echo "🐳 Building docker image: ${LOCAL_IMAGE}"
sudo sudo docker build -t "${LOCAL_IMAGE}" .

echo "🏷️ Tagging image as: ${REMOTE_IMAGE}"
sudo docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"

echo "⬆️ Pushing image: ${REMOTE_IMAGE}"
sudo docker push "${REMOTE_IMAGE}"

echo "✅ Done. Image pushed: ${REMOTE_IMAGE}"
