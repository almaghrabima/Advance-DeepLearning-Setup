#!/usr/bin/env bash
# Rebuild Docker image for linux/amd64 and push to Docker Hub
# This fixes the architecture mismatch issue (ARM64 Mac -> x86_64 Vast.ai)

set -euo pipefail

LOCAL_IMAGE="advance-deeplearning-setup"
TAG="torch2.8-cuda12.8-vastai"
REMOTE_IMAGE="almamoha/advance-deeplearning:${TAG}"

echo "🐳 Rebuilding Docker image for Vast.ai (linux/amd64)"
echo "====================================================="
echo "⚠️  Your system: $(uname -m) (ARM64)"
echo "⚠️  Building for: linux/amd64 (x86_64) - Required for Vast.ai"
echo ""

echo "🔨 Building image with --platform linux/amd64..."
docker build --platform linux/amd64 -t "${LOCAL_IMAGE}" .

echo ""
echo "🔐 Checking Docker Hub authentication..."
if [ ! -f ~/.docker/config.json ] && [ ! -f /root/.docker/config.json ]; then
    echo "⚠️  Not logged into Docker Hub. Please login:"
    docker login
elif ! grep -q "auth" ~/.docker/config.json 2>/dev/null && ! grep -q "auth" /root/.docker/config.json 2>/dev/null; then
    echo "⚠️  Not logged into Docker Hub. Please login:"
    docker login
fi

echo ""
echo "🏷️ Tagging image as: ${REMOTE_IMAGE}"
docker tag "${LOCAL_IMAGE}" "${REMOTE_IMAGE}"

echo ""
echo "⬆️ Pushing image (this may take a while)..."
docker push "${REMOTE_IMAGE}"

echo ""
echo "✅ Done! Image pushed: ${REMOTE_IMAGE}"
echo ""
echo "📝 Next steps:"
echo "   1. Update the instance to use the new image, OR"
echo "   2. Create a new instance with the corrected image"
echo ""
echo "   The image is now built for linux/amd64 and should work on Vast.ai!"
