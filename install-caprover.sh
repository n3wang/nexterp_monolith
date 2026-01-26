#!/bin/bash
# CapRover Installation Script
# This script installs CapRover on a fresh Ubuntu/Debian system

set -e

echo "🚢 CapRover Installation Script"
echo "==============================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    echo "💡 Please run ./install-docker.sh first"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running"
    echo "💡 Starting Docker..."
    systemctl start docker
    sleep 2
fi

# Get domain name
echo "📝 CapRover Setup"
echo ""
read -p "Enter your domain name (e.g., captain.yourdomain.com): " CAPROVER_DOMAIN

if [ -z "$CAPROVER_DOMAIN" ]; then
    echo "❌ Domain name is required"
    exit 1
fi

# Confirm
echo ""
echo "⚠️  CapRover will be installed with the following configuration:"
echo "   Domain: $CAPROVER_DOMAIN"
echo ""
read -p "Continue? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "❌ Installation cancelled"
    exit 1
fi

# Create CapRover network
echo "🌐 Creating CapRover network..."
docker network create caprover 2>/dev/null || echo "   Network already exists"

# Run CapRover
echo "🚀 Starting CapRover..."
docker run -d \
    --name captain \
    --restart=always \
    -p 80:80 \
    -p 443:443 \
    -p 996:996 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v /captain:/captain \
    -e CAPTAIN_DOMAIN="$CAPROVER_DOMAIN" \
    caprover/caprover:latest

# Wait for CapRover to start
echo "⏳ Waiting for CapRover to initialize (this may take a minute)..."
sleep 10

# Check if CapRover is running
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker ps | grep -q captain; then
        echo "✅ CapRover is running!"
        break
    fi
    echo "   Waiting... ($((ATTEMPT+1))/$MAX_ATTEMPTS)"
    sleep 2
    ATTEMPT=$((ATTEMPT+1))
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "❌ CapRover failed to start. Check logs:"
    echo "   docker logs captain"
    exit 1
fi

# Display information
echo ""
echo "✅ CapRover installation complete!"
echo ""
echo "📋 Access Information:"
echo "   Dashboard URL: http://$CAPROVER_DOMAIN"
echo ""
echo "🔐 Initial Setup:"
echo "   1. Open http://$CAPROVER_DOMAIN in your browser"
echo "   2. Complete the initial setup wizard"
echo "   3. Set your CapRover password"
echo "   4. Configure your domain DNS:"
echo "      - Point $CAPROVER_DOMAIN to this server's IP"
echo "      - Or use CapRover's automatic DNS (if available)"
echo ""
echo "💡 Next Steps:"
echo "   1. Complete CapRover setup in the browser"
echo "   2. Install MariaDB one-click app"
echo "   3. Deploy ERPNext using the deployment guide"
echo ""
echo "📚 Documentation:"
echo "   - CapRover Docs: https://caprover.com/docs/"
echo "   - Deployment Guide: ../CAPROVER_DEPLOYMENT_GUIDE.md"
echo ""

# Show CapRover status
echo "📊 CapRover Status:"
docker ps | grep captain

echo ""
echo "🔍 View logs: docker logs captain"
echo "🛑 Stop CapRover: docker stop captain"
echo "▶️  Start CapRover: docker start captain"
