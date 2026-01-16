#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="advance-deeplearning-setup"
TAG="torch2.8-cuda12.8-vastai"
REMOTE_IMAGE="almamoha/advance-deeplearning:${TAG}"

echo "🐳 Building docker image for Vast.ai: ${LOCAL_IMAGE}"
sudo docker build -t "${LOCAL_IMAGE}" .

echo "🔐 Checking Docker Hub authentication..."
# Check if logged in (check both user and root docker configs)
if [ ! -f ~/.docker/config.json ] && [ ! -f /root/.docker/config.json ]; then
    echo "⚠️  Not logged into Docker Hub. Please login:"
    sudo docker login
elif ! grep -q "auth" ~/.docker/config.json 2>/dev/null && ! sudo grep -q "auth" /root/.docker/config.json 2>/dev/null; then
    echo "⚠️  Not logged into Docker Hub. Please login:"
    sudo docker login
fi

echo "🏷️ Tagging image as: ${REMOTE_IMAGE}"
sudo docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"

echo "⬆️ Pushing image: ${REMOTE_IMAGE}"
sudo docker push "${REMOTE_IMAGE}"

echo "✅ Done. Vast.ai image pushed: ${REMOTE_IMAGE}"
echo "📝 Next step: Create a Vast.ai template using this image (see vastai_template_instructions.md)"
