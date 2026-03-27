#!/bin/bash
# Server Setup Script
# Prepares a fresh Ubuntu/Debian server to run the Docker Compose stack.
# Installs Docker, opens required ports, and applies system optimizations.

set -e

echo "ERPNext Docker Server Setup"
echo "============================"
echo ""
echo "This script will:"
echo "  1. Update system packages"
echo "  2. Install Docker and Docker Compose"
echo "  3. Configure firewall (ports 80, 443, 8000, 3000)"
echo "  4. Apply system optimizations for ERPNext"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    echo "Detected OS: $OS $VER"
else
    echo "ERROR: Cannot detect OS"
    exit 1
fi

read -p "Continue with setup? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Setup cancelled"
    exit 1
fi

# ─── Step 1: System update ────────────────────────────────────────────────
echo ""
echo "Step 1/4: Updating system packages"
apt-get update
apt-get upgrade -y
apt-get install -y curl wget git vim htop ufw unattended-upgrades
echo "System updated."

# ─── Step 2: Install Docker ────────────────────────────────────────────────
echo ""
echo "Step 2/4: Installing Docker"

if command -v docker &>/dev/null; then
    echo "Docker is already installed."
    docker --version
else
    apt-get install -y \
        apt-transport-https ca-certificates gnupg lsb-release software-properties-common

    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    systemctl start docker
    systemctl enable docker

    # Standalone docker-compose (for scripts that use it directly)
    DC_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DC_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker "$SUDO_USER"
    fi
fi

echo "Docker installed."
docker --version
docker-compose --version 2>/dev/null || docker compose version

# ─── Step 3: Firewall ───────────────────────────────────────────────────────────────
echo ""
echo "Step 3/4: Configuring firewall"

if command -v ufw &>/dev/null; then
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 8000/tcp  # ERPNext backend
    ufw allow 3000/tcp  # React frontend

    echo "WARNING: Firewall will be enabled. Ensure SSH (port 22) is allowed."
    read -p "Enable firewall? (y/N): " ENABLE_FW
    if [ "$ENABLE_FW" = "y" ] || [ "$ENABLE_FW" = "Y" ]; then
        ufw --force enable
        echo "Firewall enabled."
    else
        echo "Firewall not enabled. Run: ufw enable"
    fi
else
    echo "UFW not available, skipping firewall."
fi

# ─── Step 4: System optimizations ────────────────────────────────────────────────
echo ""
echo "Step 4/4: System optimizations"

if ! grep -q "fs.file-max" /etc/sysctl.conf; then
    cat >> /etc/sysctl.conf <<-EOF

# ERPNext Docker optimizations
fs.file-max = 2097152
vm.max_map_count = 262144
net.core.somaxconn = 65535
EOF
    sysctl -p
    echo "System limits increased."
else
    echo "System limits already configured."
fi

# ─── Summary ───────────────────────────────────────────────────────────────────────────
echo ""
echo "============================"
echo "Server setup complete."
echo "============================"
echo ""
echo "Next steps:"
echo "  1. Copy nexterp_monolith/ to this server (e.g. via scp or git clone)"
echo "  2. Edit .env with your passwords and domain"
echo "  3. Run: docker compose up -d --build"
echo "  4. React app: http://<server-ip>:3000"
echo "  5. ERPNext API: http://<server-ip>:8000"
echo ""
if [ -n "$SUDO_USER" ]; then
    echo "NOTE: $SUDO_USER was added to the docker group."
    echo "Log out and back in for it to take effect."
fi


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
    echo "📋 Detected OS: $OS $VER"
else
    echo "❌ Cannot detect OS"
    exit 1
fi

# Confirm
read -p "Continue with setup? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "❌ Setup cancelled"
    exit 1
fi

echo ""
echo "🚀 Starting setup..."
echo ""

# Step 1: Update system
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/5: Updating system packages"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
apt-get update
apt-get upgrade -y
apt-get install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    ufw \
    unattended-upgrades

echo "✅ System updated"
echo ""

# Step 2: Install Docker
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/5: Installing Docker"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v docker &> /dev/null; then
    echo "ℹ️  Docker is already installed"
    docker --version
else
    # Install prerequisites
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common

    # Remove old Docker versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg

    # Set up Docker repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
      $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Start and enable Docker
    systemctl start docker
    systemctl enable docker

    # Install Docker Compose
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Add current user to docker group
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
    fi
fi

echo "✅ Docker installed"
docker --version
echo ""

# Step 3: Configure Firewall
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/5: Configuring firewall"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if command -v ufw &> /dev/null; then
    # Allow SSH (important!)
    ufw allow 22/tcp
    
    # Allow CapRover ports
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw allow 996/tcp
    
    # Enable firewall (with confirmation)
    echo "⚠️  Firewall will be enabled. Make sure SSH (port 22) is allowed!"
    read -p "Enable firewall? (y/N): " ENABLE_FW
    if [ "$ENABLE_FW" = "y" ] || [ "$ENABLE_FW" = "Y" ]; then
        ufw --force enable
        echo "✅ Firewall enabled"
    else
        echo "ℹ️  Firewall not enabled (you can enable it later with: ufw enable)"
    fi
else
    echo "ℹ️  UFW not available, skipping firewall configuration"
fi
echo ""

# Step 4: System Optimizations
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/5: System optimizations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Increase file descriptor limits
if ! grep -q "fs.file-max" /etc/sysctl.conf; then
    echo "" >> /etc/sysctl.conf
    echo "# ERPNext/CapRover optimizations" >> /etc/sysctl.conf
    echo "fs.file-max = 2097152" >> /etc/sysctl.conf
    echo "vm.max_map_count = 262144" >> /etc/sysctl.conf
    sysctl -p
    echo "✅ System limits increased"
else
    echo "ℹ️  System limits already configured"
fi

# Configure automatic security updates
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    echo "✅ Automatic security updates configured"
fi

echo ""

# Step 5: Install CapRover
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5/5: Installing CapRover"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker ps -a | grep -q captain; then
    echo "ℹ️  CapRover container already exists"
    read -p "Remove existing CapRover and reinstall? (y/N): " REINSTALL
    if [ "$REINSTALL" = "y" ] || [ "$REINSTALL" = "Y" ]; then
        docker stop captain 2>/dev/null || true
        docker rm captain 2>/dev/null || true
    else
        echo "ℹ️  Keeping existing CapRover installation"
        echo ""
        echo "✅ Setup complete!"
        exit 0
    fi
fi

# Get domain name
read -p "Enter your CapRover domain (e.g., captain.yourdomain.com): " CAPROVER_DOMAIN

if [ -z "$CAPROVER_DOMAIN" ]; then
    echo "⚠️  No domain provided. You can install CapRover later with: ./install-caprover.sh"
else
    # Create CapRover network
    docker network create caprover 2>/dev/null || true

    # Run CapRover
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

    echo "⏳ Waiting for CapRover to initialize..."
    sleep 10
    
    echo "✅ CapRover installed!"
    echo "   Dashboard: http://$CAPROVER_DOMAIN"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Server setup complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "   ✅ System updated"
echo "   ✅ Docker installed"
if [ "$ENABLE_FW" = "y" ] || [ "$ENABLE_FW" = "Y" ]; then
    echo "   ✅ Firewall configured"
fi
echo "   ✅ System optimized"
if [ -n "$CAPROVER_DOMAIN" ]; then
    echo "   ✅ CapRover installed"
fi
echo ""
echo "💡 Next Steps:"
if [ -n "$CAPROVER_DOMAIN" ]; then
    echo "   1. Configure DNS: Point $CAPROVER_DOMAIN to this server's IP"
    echo "   2. Open http://$CAPROVER_DOMAIN in your browser"
    echo "   3. Complete CapRover setup wizard"
else
    echo "   1. Install CapRover: ./install-caprover.sh"
fi
echo "   2. Install MariaDB one-click app in CapRover"
echo "   3. Deploy ERPNext using the deployment guide"
echo ""
echo "📚 Documentation:"
echo "   - Deployment Guide: ../CAPROVER_DEPLOYMENT_GUIDE.md"
echo "   - Quick Reference: ../CAPROVER_QUICK_REFERENCE.md"
echo ""
if [ -n "$SUDO_USER" ]; then
    echo "⚠️  Note: User $SUDO_USER was added to docker group"
    echo "   You may need to log out and back in for changes to take effect"
    echo ""
fi
