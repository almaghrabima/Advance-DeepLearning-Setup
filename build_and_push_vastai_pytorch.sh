#!/usr/bin/env bash
set -euo pipefail

LOCAL_IMAGE="advance-deeplearning-setup"
TAG="vastai-pytorch-automatic"
REMOTE_IMAGE="almamoha/advance-deeplearning:${TAG}"

echo "🐳 Building docker image for Vast.ai with vastai/pytorch base (linux/amd64 platform): ${LOCAL_IMAGE}"
echo "⚠️  Building for linux/amd64 platform (required for Vast.ai x86_64 instances)"
echo "   Using Dockerfile.vastai-pytorch with base: vastai/pytorch:cuda-13.0.2-auto"
echo "   Note: In Vast.ai templates, you can use [Automatic] tag selection"
echo ""
sudo docker build --platform linux/amd64 -f Dockerfile.vastai-pytorch -t "${LOCAL_IMAGE}" .

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

echo "✅ Done. Vast.ai PyTorch image pushed: ${REMOTE_IMAGE}"
echo "📝 Next step: Create a Vast.ai template using this image (see vastai_template_instructions.md)"
