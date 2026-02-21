#!/usr/bin/env bash
set -euo pipefail

# Load .env for DOCKER_PAT (Docker Hub login). GITHUB_PAT is NOT baked into the image;
# pass GITHUB_PAT and PROJECT_REPO (or GITHUB_REPO) as env in your Vast.ai template.
if [ -f .env ]; then
  set -a
  # shellcheck source=/dev/null
  source .env
  set +a
  echo "📁 Loaded .env (DOCKER_PAT used for Docker Hub login only; no secrets in image)"
fi

LOCAL_IMAGE="advance-deeplearning-setup"
TAG="vastai-pytorch-automatic"
REMOTE_IMAGE="almamoha/advance-deeplearning:${TAG}"

echo "🐳 Building docker image for Vast.ai (linux/amd64): ${REMOTE_IMAGE}"
echo "   Using Dockerfile.vastai-pytorch with base: vastai/pytorch:cuda-13.0.2-auto"
echo "   Clone uses GITHUB_PAT + PROJECT_REPO at runtime (set in Vast.ai template)."
echo ""
sudo docker build --platform linux/amd64 -f Dockerfile.vastai-pytorch -t "${LOCAL_IMAGE}" .

echo "🔐 Docker Hub authentication..."
if [ -n "${DOCKER_PAT:-}" ]; then
  echo "${DOCKER_PAT}" | sudo docker login -u almamoha --password-stdin docker.io
  echo "   Logged in with DOCKER_PAT from .env"
elif [ ! -f ~/.docker/config.json ] && [ ! -f /root/.docker/config.json ]; then
  echo "⚠️  Not logged in. Set DOCKER_PAT in .env or run: sudo docker login"
  sudo docker login
elif ! grep -q "auth" ~/.docker/config.json 2>/dev/null && ! sudo grep -q "auth" /root/.docker/config.json 2>/dev/null; then
  echo "⚠️  No auth found. Set DOCKER_PAT in .env or run: sudo docker login"
  sudo docker login
else
  echo "   Using existing Docker credentials"
fi

echo "🏷️ Tagging: ${REMOTE_IMAGE}"
sudo docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"

echo "⬆️ Pushing: ${REMOTE_IMAGE}"
sudo docker push "${REMOTE_IMAGE}"

echo "✅ Done. Image pushed: ${REMOTE_IMAGE}"
echo "📝 When GITHUB_PAT expires: update GITHUB_PAT in your Vast.ai template env only (no rebuild needed)."
echo "   Template env example: PROJECT_REPO=... GITHUB_REPO=... GITHUB_PAT=<your_new_token>"
