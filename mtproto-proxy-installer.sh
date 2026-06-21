#!/bin/sh

# Exit immediately if any command fails
set -e

# Prompt the user for the port number (POSIX compliant)
echo "=================================================="
printf "Enter the port number for the proxy [Default: 443]: "
read PORT < /dev/tty
PORT=${PORT:-443}
echo "Proxy will be bound to port: $PORT"
echo "=================================================="

CONFIG_FILE="/etc/mtg.toml"
BINARY_PATH="/usr/local/bin/mtg"

# 1. OS Detection
if [ -f /etc/alpine-release ]; then
    OS="alpine"
    SERVICE_FILE="/etc/init.d/mtg"
elif grep -qi 'debian\|ubuntu\|mint' /etc/os-release 2>/dev/null; then
    OS="debian"
    SERVICE_FILE="/etc/systemd/system/mtg.service"
else
    echo "ERROR: This script currently only supports Debian/Ubuntu and Alpine Linux."
    exit 1
fi

# 2. Update and Install Dependencies
echo "=== Updating package lists and installing dependencies ==="
if [ "$OS" = "alpine" ]; then
    apk update
    apk add curl wget tar ca-certificates iproute2 libc6-compat
elif [ "$OS" = "debian" ]; then
    apt update
    apt install -y curl wget tar ca-certificates iproute2
fi

# Check if the chosen port is already in use
if ss -tuln | grep -q ":$PORT "; then
    echo "ERROR: Port $PORT is already in use by another service!"
    exit 1
fi

# 3. Download and Install Binary
echo "=== Fetching and downloading the latest 'mtg' binary ==="
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/9seconds/mtg/releases/latest | grep browser_download_url | grep linux-amd64.tar.gz | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Could not fetch the download URL from GitHub."
    exit 1
fi

wget -O mtg_latest.tar.gz "$DOWNLOAD_URL"

echo "=== Extracting and installing binary ==="
tar -xzf mtg_latest.tar.gz
mv mtg-*/mtg "$BINARY_PATH"
chmod +x "$BINARY_PATH"
rm -rf mtg-* mtg_latest.tar.gz

# 4. Configure
echo "=== Generating proxy secret ==="
SECRET=$("$BINARY_PATH" generate-secret google.com)

echo "=== Creating configuration file ==="
cat << EOF > "$CONFIG_FILE"
secret = "$SECRET"
bind-to = "0.0.0.0:$PORT"
EOF

# 5. Create Background Service
echo "=== Creating system service ==="
if [ "$OS" = "alpine" ]; then
    cat << 'EOF' > "$SERVICE_FILE"
#!/sbin/openrc-run

name="mtg"
description="MTProto Proxy Server"
command="/usr/local/bin/mtg"
command_args="run /etc/mtg.toml"
command_background="yes"
pidfile="/run/mtg.pid"

depend() {
    need net
}
EOF
    chmod +x "$SERVICE_FILE"
    rc-update add mtg default
    rc-service mtg stop 2>/dev/null || true
    rc-service mtg start
elif [ "$OS" = "debian" ]; then
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=MTProto Proxy Server (mtg)
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH run $CONFIG_FILE
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now mtg
fi

sleep 2

# 6. Verify and Print Links
IS_RUNNING="false"
if [ "$OS" = "alpine" ]; then
    if rc-service mtg status | grep -q "started"; then
        IS_RUNNING="true"
    fi
elif [ "$OS" = "debian" ]; then
    if systemctl is-active --quiet mtg; then
        IS_RUNNING="true"
    fi
fi

if [ "$IS_RUNNING" = "true" ]; then
    # Fetch IP safely with a timeout to prevent hanging
    SERVER_IP=$(curl -s4 --max-time 3 ifconfig.me || echo "YOUR_SERVER_IP")
    echo "=================================================="
    echo " SUCCESS: MTProto Proxy Installed Successfully!"
    echo "=================================================="
    echo "tg://proxy?server=$SERVER_IP&port=$PORT&secret=$SECRET"
    echo "https://t.me/proxy?server=$SERVER_IP&port=$PORT&secret=$SECRET"
    echo "=================================================="
else
    echo "=================================================="
    echo " ERROR: The proxy service failed to start."
    if [ "$OS" = "alpine" ]; then
        echo " Please run: rc-service mtg status for details."
    else
        echo " Please run: systemctl status mtg for details."
    fi
    echo "=================================================="
    exit 1
fi
