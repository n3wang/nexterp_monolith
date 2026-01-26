#!/bin/bash
# Docker Installation Script for Ubuntu/Debian
# This script installs Docker and Docker Compose on a fresh Ubuntu/Debian system

set -e

echo "🐳 Docker Installation Script"
echo "=============================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    echo "❌ Cannot detect OS"
    exit 1
fi

echo "📋 Detected OS: $OS $VER"
echo ""

# Update system
echo "🔄 Updating system packages..."
apt-get update
apt-get upgrade -y

# Install prerequisites
echo "📦 Installing prerequisites..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Remove old Docker versions if any
echo "🧹 Removing old Docker versions (if any)..."
apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# Add Docker's official GPG key
echo "🔑 Adding Docker's official GPG key..."
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

# Set up Docker repository
echo "📝 Setting up Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index
echo "🔄 Updating package index..."
apt-get update

# Install Docker Engine, CLI, and Containerd
echo "📦 Installing Docker Engine..."
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker
echo "🚀 Starting Docker service..."
systemctl start docker
systemctl enable docker

# Install Docker Compose (standalone)
echo "📦 Installing Docker Compose..."
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Add current user to docker group (if not root)
if [ -n "$SUDO_USER" ]; then
    echo "👤 Adding $SUDO_USER to docker group..."
    usermod -aG docker $SUDO_USER
    echo "✅ User $SUDO_USER added to docker group"
    echo "⚠️  You may need to log out and back in for group changes to take effect"
fi

# Verify installation
echo ""
echo "✅ Docker installation complete!"
echo ""
echo "🔍 Verifying installation..."
docker --version
docker compose version

echo ""
echo "📋 Docker status:"
systemctl status docker --no-pager | head -n 3

echo ""
echo "✅ Docker is ready to use!"
echo ""
echo "💡 Next steps:"
echo "   1. If you added a user to docker group, log out and back in"
echo "   2. Test Docker: docker run hello-world"
echo "   3. Install CapRover: ./install-caprover.sh"
