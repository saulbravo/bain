#!/bin/bash

# Bolls Bible Local Setup Script
# This script automates the setup process as much as possible

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "Bolls Bible Local Setup"
echo "=========================================="
echo ""

# Check for required tools
echo "Checking for required tools..."

# Check for make
if ! command -v make &> /dev/null; then
    echo "❌ 'make' is not installed."
    echo "   Please install it with: sudo dnf install -y make"
    exit 1
fi
echo "✅ make is installed"

# Check for podman or docker
if command -v podman &> /dev/null; then
    DOCKER_CMD="podman"
    echo "✅ podman is installed"
elif command -v docker &> /dev/null; then
    DOCKER_CMD="docker"
    echo "✅ docker is installed"
else
    echo "❌ Neither podman nor docker is installed."
    exit 1
fi

# Check for docker-compose or podman-compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
    echo "✅ docker-compose is installed"
elif command -v podman-compose &> /dev/null; then
    COMPOSE_CMD="podman-compose"
    echo "✅ podman-compose is installed"
elif $DOCKER_CMD compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="$DOCKER_CMD compose"
    echo "✅ $DOCKER_CMD compose is available"
else
    echo "❌ docker-compose or podman-compose is not available."
    echo "   Please install it with: sudo dnf install -y docker-compose"
    echo "   Or: sudo dnf install -y podman-compose"
    exit 1
fi

echo ""
echo "=========================================="
echo "Step 1: Checking /etc/hosts"
echo "=========================================="

if grep -q "bolls.local" /etc/hosts 2>/dev/null; then
    echo "✅ bolls.local is already in /etc/hosts"
else
    echo "⚠️  bolls.local is NOT in /etc/hosts"
    echo "   Please add it manually with:"
    echo "   echo '127.0.0.1 bolls.local' | sudo tee -a /etc/hosts"
    read -p "Press Enter to continue (you can add it later)..."
fi

echo ""
echo "=========================================="
echo "Step 2: Creating .env.dev file"
echo "=========================================="

if [ ! -f .env.dev ]; then
    touch .env.dev
    echo "✅ Created .env.dev file"
else
    echo "✅ .env.dev file already exists"
fi

echo ""
echo "=========================================="
echo "Step 3: Creating Docker network"
echo "=========================================="

if $DOCKER_CMD network inspect web &> /dev/null 2>&1; then
    echo "✅ Docker network 'web' already exists"
else
    $DOCKER_CMD network create web
    echo "✅ Created Docker network 'web'"
fi

echo ""
echo "=========================================="
echo "Step 4: Installing mkcert and generating certificates"
echo "=========================================="

if command -v mkcert &> /dev/null; then
    echo "✅ mkcert is installed"
    if [ -f traefik/certs/local-cert.pem ] && [ -f traefik/certs/local-key.pem ]; then
        echo "✅ SSL certificates already exist"
    else
        echo "Generating SSL certificates..."
        chmod +x mkcert/mkcert-install.sh mkcert/mkcert-certs.sh
        ./mkcert/mkcert-install.sh
        ./mkcert/mkcert-certs.sh
        echo "✅ SSL certificates generated"
    fi
else
    echo "⚠️  mkcert is not installed. Installing..."
    chmod +x mkcert/mkcert-install.sh mkcert/mkcert-certs.sh
    ./mkcert/mkcert-install.sh
    ./mkcert/mkcert-certs.sh
    echo "✅ mkcert installed and certificates generated"
fi

echo ""
echo "=========================================="
echo "Step 5: Building Docker images"
echo "=========================================="

echo "This may take several minutes..."
$COMPOSE_CMD build

echo ""
echo "=========================================="
echo "Step 6: System configuration"
echo "=========================================="

echo "⚠️  For Linux, you may need to allow non-root binding to port 80:"
echo "   sudo sysctl net.ipv4.ip_unprivileged_port_start=80"
echo "   To make it permanent, add to /etc/sysctl.conf:"
echo "   net.ipv4.ip_unprivileged_port_start=80"
read -p "Press Enter to continue..."

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps (run these commands):"
echo ""
echo "1. Start the containers:"
echo "   $COMPOSE_CMD up -d"
echo "   (or 'make up' if you have make installed)"
echo ""
echo "2. Run database migrations:"
echo "   $COMPOSE_CMD exec django python manage.py migrate"
echo "   (or 'make migrate')"
echo ""
echo "3. Create a superuser:"
echo "   $COMPOSE_CMD exec django python manage.py createsuperuser"
echo "   (or 'make createsuperuser')"
echo ""
echo "4. Restore database with all translations:"
echo "   make restore-db"
echo "   (This downloads and restores all translations and data)"
echo ""
echo "5. Access the application at:"
echo "   https://bolls.local"
echo ""
echo "=========================================="

