#!/usr/bin/env bash
# Fix port conflict issues for Vast.ai instances
# Usage: ./fix_port_conflict_vastai.sh [port]

set -euo pipefail

PORT="${1:-52405}"

echo "🔍 Diagnosing Port Conflict"
echo "=========================="
echo "Port: $PORT"
echo ""

# Check what's using the port
echo "1️⃣ Checking what's using port $PORT..."

if command -v lsof > /dev/null 2>&1; then
    echo "   Using lsof to find process..."
    LSOF_OUTPUT=$(lsof -i :$PORT 2>/dev/null || echo "")
    if [ -n "$LSOF_OUTPUT" ]; then
        echo "   Found process using port $PORT:"
        echo "$LSOF_OUTPUT"
        echo ""
        
        # Extract PID
        PID=$(echo "$LSOF_OUTPUT" | awk 'NR==2 {print $2}')
        if [ -n "$PID" ]; then
            echo "   Process ID: $PID"
            echo "   Process details:"
            ps -p "$PID" -o pid,ppid,user,command 2>/dev/null || echo "   Process may have exited"
            echo ""
            
            echo "2️⃣ Options to fix:"
            echo ""
            echo "   Option A: Kill the process using the port"
            echo "   ⚠️  WARNING: This will terminate the process!"
            echo "   Run: sudo kill -9 $PID"
            echo ""
            echo "   Option B: Wait for the process to finish"
            echo "   The process may be a previous instance that's shutting down"
            echo ""
            echo "   Option C: Use a different port (if creating new instance)"
            echo "   Vast.ai will assign a different port automatically"
        fi
    else
        echo "   ✅ Port $PORT is not in use (or lsof couldn't detect it)"
    fi
elif command -v netstat > /dev/null 2>&1; then
    echo "   Using netstat to find process..."
    NETSTAT_OUTPUT=$(netstat -tulpn 2>/dev/null | grep ":$PORT " || echo "")
    if [ -n "$NETSTAT_OUTPUT" ]; then
        echo "   Found process using port $PORT:"
        echo "$NETSTAT_OUTPUT"
    else
        echo "   ✅ Port $PORT is not in use"
    fi
elif command -v ss > /dev/null 2>&1; then
    echo "   Using ss to find process..."
    SS_OUTPUT=$(ss -tulpn 2>/dev/null | grep ":$PORT " || echo "")
    if [ -n "$SS_OUTPUT" ]; then
        echo "   Found process using port $PORT:"
        echo "$SS_OUTPUT"
    else
        echo "   ✅ Port $PORT is not in use"
    fi
else
    echo "   ⚠️  No port checking tools available (lsof, netstat, or ss)"
    echo "   Install one: brew install lsof (on macOS)"
fi

echo ""
echo "3️⃣ Vast.ai Specific Solutions"
echo "=============================="
echo ""
echo "If this is a Vast.ai instance port conflict:"
echo ""
echo "   Option 1: Stop the existing instance"
echo "   vastai stop instance <instance_id>"
echo "   # Wait a few seconds, then try again"
echo ""
echo "   Option 2: Destroy and recreate the instance"
echo "   vastai destroy instance <instance_id>"
echo "   vastai create instance <template_hash> --price <price>"
echo ""
echo "   Option 3: Check for zombie/stopped instances"
echo "   vastai show instances"
echo "   # Look for instances in 'stopped' or 'error' state"
echo "   vastai destroy instance <stopped_instance_id>"
echo ""
echo "   Option 4: If port is stuck, kill the process (see Option A above)"
echo ""

# Check for Docker containers using the port
echo "4️⃣ Checking Docker containers..."
if command -v docker > /dev/null 2>&1; then
    DOCKER_CONTAINERS=$(docker ps -a --filter "publish=$PORT" --format "{{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "")
    if [ -n "$DOCKER_CONTAINERS" ]; then
        echo "   Docker containers using port $PORT:"
        echo "$DOCKER_CONTAINERS"
        echo ""
        echo "   To remove stopped containers:"
        echo "   docker ps -a --filter 'publish=$PORT' --format '{{.ID}}' | xargs docker rm"
    else
        echo "   ✅ No Docker containers found using port $PORT"
    fi
else
    echo "   ⚠️  Docker not available"
fi

echo ""
echo "💡 Quick Fix Commands"
echo "===================="
echo ""
echo "If you know the process ID (PID) from above:"
echo "   sudo kill -9 <PID>"
echo ""
echo "If it's a Vast.ai instance:"
echo "   # List instances"
echo "   vastai show instances"
echo ""
echo "   # Stop the conflicting instance"
echo "   vastai stop instance <instance_id>"
echo ""
echo "   # Or destroy it"
echo "   vastai destroy instance <instance_id>"
echo ""
