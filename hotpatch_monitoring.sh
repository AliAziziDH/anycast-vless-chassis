#!/bin/bash
# hotpatch_monitoring.sh
# Automated hotpatch to deploy the Telemetry API daemon and update Nginx configs.

set -e

echo "Starting Telemetry Hotpatch..."

# 1. Setup the Web Dashboard
echo "Copying dashboard files..."
mkdir -p /var/www/html/stats
cp stats/index.html /var/www/html/stats/index.html

# 2. Setup the Telemetry API Daemon
echo "Setting up Telemetry API Daemon..."
mkdir -p /usr/local/bin
cp bin/vpn-stats-api /usr/local/bin/vpn-stats-api
chmod +x /usr/local/bin/vpn-stats-api

cat << 'EOF' > /etc/systemd/system/vpn-stats-api.service
[Unit]
Description=VPN Telemetry API Daemon
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/vpn-stats-api
Restart=on-failure
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable vpn-stats-api.service
systemctl start vpn-stats-api.service

# 3. Patch Nginx Configuration
NGINX_CONF="/etc/nginx/sites-available/default"
LOG_CONF="/etc/nginx/conf.d/vpn_log.conf"

if [ ! -f "$NGINX_CONF" ]; then
    echo "Warning: $NGINX_CONF not found. Skipping Nginx hotpatch."
    exit 0
fi

# Apply Log Config if not present
if [ ! -f "$LOG_CONF" ]; then
    echo "Adding custom JSON log format..."
    cat << 'EOF' > "$LOG_CONF"
log_format vpn_json escape=json '{'
    '"time_local": "$time_local",'
    '"remote_addr": "$remote_addr",'
    '"cf_connecting_ip": "$http_cf_connecting_ip",'
    '"request": "$request",'
    '"status": "$status",'
    '"body_bytes_sent": "$body_bytes_sent",'
    '"http_user_agent": "$http_user_agent"'
'}';
EOF
fi

# Inject location blocks if missing
if ! grep -q "location /stats/" "$NGINX_CONF"; then
    echo "Injecting /stats/ location..."
    sed -i '/location \/ws {/i \    location /stats/ {\
        alias /var/www/html/stats/;\
        index index.html;\
    }\
' "$NGINX_CONF"
fi

if ! grep -q "location /api/telemetry" "$NGINX_CONF"; then
    echo "Injecting /api/telemetry proxy..."
    sed -i '/location \/ws {/i \    location /api/telemetry {\
        proxy_pass http://127.0.0.1:8080/api/telemetry;\
        proxy_buffering off;\
        tcp_nodelay on;\
    }\
' "$NGINX_CONF"
fi

# Add access_log to /ws if missing
if ! grep -q "access_log /var/log/nginx/vpn_access.log vpn_json;" "$NGINX_CONF"; then
    echo "Enabling access log for /ws..."
    sed -i '/location \/ws {/a \        access_log /var/log/nginx/vpn_access.log vpn_json;' "$NGINX_CONF"
fi

# Setup stub_status for connections on 8081
if ! grep -q "listen 127.0.0.1:8081;" "$NGINX_CONF"; then
    echo "Setting up Nginx stub_status..."
    cat << 'EOF' >> "$NGINX_CONF"

server {
    listen 127.0.0.1:8081;
    server_name localhost;
    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
EOF
fi

# 4. Validate and Reload Nginx
echo "Validating Nginx configuration..."
if nginx -t; then
    echo "Configuration is valid. Reloading Nginx gracefully..."
    systemctl reload nginx
    echo "Hotpatch completed successfully. Dashboard is live at /stats/ !"
else
    echo "Error: Nginx configuration is invalid. Aborting reload."
    exit 1
fi
