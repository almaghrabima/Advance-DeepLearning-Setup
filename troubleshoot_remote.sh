#!/usr/bin/env bash
# Commands to run on the Vast.ai instance to troubleshoot

cat << 'EOF'
# Run these commands on the Vast.ai instance (via SSH):

echo "🔍 Troubleshooting Vast.ai Instance"
echo "===================================="
echo ""

echo "1. Check Docker containers:"
docker ps
docker ps -a
echo ""

echo "2. Check environment variables:"
env | grep -E "GIT_USER|WANDB|PROJECT_REPO|GITHUB|HF_"
echo ""

echo "3. Check if start script exists:"
ls -la /usr/local/bin/start-project.sh
cat /usr/local/bin/start-project.sh | head -20
echo ""

echo "4. Check workspace directory:"
ls -la /workspace
echo ""

echo "5. Check Docker logs (if container exists):"
CONTAINER_ID=$(docker ps -a -q | head -1)
if [ -n "$CONTAINER_ID" ]; then
    echo "Container ID: $CONTAINER_ID"
    docker logs $CONTAINER_ID | tail -50
else
    echo "No containers found"
fi
echo ""

echo "6. Check if image was pulled:"
docker images | grep advance-deeplearning
echo ""

echo "7. Try to manually run start script:"
if [ -f /usr/local/bin/start-project.sh ]; then
    echo "Script exists, checking if it can run..."
    bash -x /usr/local/bin/start-project.sh 2>&1 | head -30
else
    echo "Script not found!"
fi

EOF
