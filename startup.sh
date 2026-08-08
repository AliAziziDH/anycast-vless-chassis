#!/bin/bash
# startup.sh - Public VLESS-WS with Cloudflare Tunnel configuration script
# Optimized with Google BBR, Nginx buffer overrides, and Standard Port 443

# Exit on any command failure
set -e

# ====================================================================
# 1. System Networking Optimizations (Google BBR & TCP Window Tuning)
# ====================================================================
echo "Configuring network kernel parameters..."

# Enable BBR Congestion Control and Fair Queueing packet scheduling
# We write to sysctl.d to be compatible with modern Debian/Ubuntu standards
cat << 'EOF' > /etc/sysctl.d/99-anycast-vpn.conf
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_window_scaling=1
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
# Scale TCP memory buffers for high-latency transcontinental transits
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
EOF

# Load and apply the new network rules
sysctl --system

# ====================================================================
# 2. Install Package Dependencies
# ====================================================================
echo "Updating package lists and installing dependencies..."
apt-get update
apt-get install -y curl uuid-runtime jq python3 nginx

# Install Xray-core release package
echo "Installing Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# ====================================================================
# 3. Configure Xray Core Inbound (VLESS-over-WS)
# ====================================================================
echo "Writing Xray configuration..."
UUID=$(uuidgen)

# Unquoted EOF allows $UUID expansion by bash
cat << EOF > /usr/local/etc/xray/config.json
{
  "inbounds": [
    {
      "port": 10000,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "level": 8
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/ws"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF

# Start/Restart Xray
systemctl restart xray

# ====================================================================
# 4. Configure Nginx Reverse Proxy (Zero-Buffer WebSockets)
# ====================================================================
echo "Writing Nginx reverse proxy configuration..."

# We write our server block, escaping Nginx variables with backslashes
cat << 'EOF' > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html index.htm;
    server_name _;

    # Proxy VLESS WebSocket connections directly to Xray loopback
    location /ws {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10000;
        proxy_http_version 1.1;

        # WebSocket handshake headers
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;

        # Real IP extraction headers
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # CRITICAL optimizations for latency reduction
        proxy_buffering off;             # Disable response buffering
        proxy_read_timeout 86400s;       # Keep connection open for 24h
        proxy_send_timeout 86400s;       # Prevent idle socket dropping
        tcp_nodelay on;                  # Disable Nagle's delay algorithm
    }
}
EOF

# Restart Nginx
systemctl restart nginx

# ====================================================================
# 5. Set up Cloudflare Tunnel (Quick Tunnel Daemon)
# ====================================================================
echo "Downloading and installing cloudflared..."
curl -L -o cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared.deb

echo "Creating cloudflared systemd service..."
cat << 'EOF' > /etc/systemd/system/cloudflared-tunnel.service
[Unit]
Description=Cloudflare Quick Tunnel Service
After=network.target

[Service]
TimeoutStartSec=0
Type=simple
ExecStart=/usr/bin/cloudflared tunnel --url http://localhost:80
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudflared-tunnel
systemctl start cloudflared-tunnel

# ====================================================================
# 6. Polling for trycloudflare.com Domain Name
# ====================================================================
echo "Waiting for Cloudflare Tunnel URL generation..."
TUNNEL_URL=""
for i in {1..30}; do
    TUNNEL_URL=$(journalctl -u cloudflared-tunnel --no-pager | grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' | tail -n 1 | sed 's/https:\/\///' || true)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    sleep 2
done

if [ -z "$TUNNEL_URL" ]; then
    echo "ERROR: Could not retrieve Cloudflare Tunnel URL within 60 seconds."
    exit 1
fi

echo "Cloudflare Tunnel successfully generated: $TUNNEL_URL"

# ====================================================================
# 7. Generate Multi-Node Anycast Subscription Profile (Port 443)
# ====================================================================
echo "Generating subscription profiles..."

# Standard, clean Anycast IP blocks mapped to standard secure port 443
VLESS_URI_1="vless://${UUID}@104.17.147.22:443?type=ws&security=tls&path=%2Fws&sni=${TUNNEL_URL}&host=${TUNNEL_URL}#🇺🇸%20Anycast-CDN-1"
VLESS_URI_2="vless://${UUID}@104.16.132.229:443?type=ws&security=tls&path=%2Fws&sni=${TUNNEL_URL}&host=${TUNNEL_URL}#🇺🇸%20Anycast-CDN-2"
VLESS_URI_3="vless://${UUID}@162.159.135.42:443?type=ws&security=tls&path=%2Fws&sni=${TUNNEL_URL}&host=${TUNNEL_URL}#🇺🇸%20Anycast-CDN-3"
VLESS_URI_4="vless://${UUID}@172.67.147.22:443?type=ws&security=tls&path=%2Fws&sni=${TUNNEL_URL}&host=${TUNNEL_URL}#🇺🇸%20Anycast-CDN-4"

# Create a sub directory to serve the subscription file
SUB_DIR="/var/www/html/sub"
mkdir -p "$SUB_DIR"

# Join URIs with newlines, base64 encode them in one flat string, and host it on Nginx
echo -e "${VLESS_URI_1}\n${VLESS_URI_2}\n${VLESS_URI_3}\n${VLESS_URI_4}" | base64 -w 0 > "$SUB_DIR/index.html"

# Save the final URL locally so our deployment check script can grab it
echo "https://${TUNNEL_URL}/sub/" > /root/subscription_url.txt
echo "=========================================================="
echo "SUCCESS! Subscription served at: https://${TUNNEL_URL}/sub/"
echo "=========================================================="
