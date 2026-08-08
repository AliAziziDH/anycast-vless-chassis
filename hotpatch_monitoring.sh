#!/bin/bash
# hotpatch_monitoring.sh
# Configures Nginx with active stub_status on localhost and reloads seamlessly.

set -e

echo "Starting Nginx hotpatch for monitoring..."

# Define the stub_status server block
STATUS_BLOCK="
server {
    listen 127.0.0.1:8080;
    server_name localhost;

    location /nginx_status {
        stub_status;
        allow 127.0.0.1;
        deny all;
    }
}
"

NGINX_CONF="/etc/nginx/sites-available/default"

if [ ! -f "$NGINX_CONF" ]; then
    echo "Warning: $NGINX_CONF not found. Skipping hotpatch."
    exit 0
fi

# Check if stub_status is already configured to avoid duplicates
if grep -q "location /nginx_status" "$NGINX_CONF"; then
    echo "Nginx stub_status is already configured."
else
    echo "Injecting Nginx stub_status configuration..."
    # Append the server block to the configuration
    echo "$STATUS_BLOCK" >> "$NGINX_CONF"
fi

echo "Validating Nginx configuration..."
if nginx -t; then
    echo "Configuration is valid. Reloading Nginx gracefully..."
    systemctl reload nginx
    echo "Nginx reloaded successfully. Monitoring active."
else
    echo "Error: Nginx configuration is invalid. Aborting reload."
    exit 1
fi
