#!/bin/bash
# deploy_gcp.sh - Provision GCP e2-micro infrastructure for Anycast VLESS VPN
# Automatically configured for GCP Always-Free Tier eligibility

set -e

# Dynamically fetch the current project ID configured in gcloud CLI
PROJECT_ID=$(gcloud config get-value project 2>/dev/null || true)

if [ -z "$PROJECT_ID" ]; then
    echo "ERROR: No active Google Cloud project configured."
    echo "Please set your project first using: gcloud config set project YOUR_PROJECT_ID"
    exit 1
fi

# Parameterized region (defaulting to us-central1 for Always-Free VM eligibility)
REGION="${1:-us-central1}"
ZONE="${REGION}-a"
INSTANCE_NAME="xray-vpn-node"

echo "=========================================================="
echo "Project ID : $PROJECT_ID"
echo "Region     : $REGION"
echo "Zone       : $ZONE"
echo "VM Name    : $INSTANCE_NAME"
echo "=========================================================="

# Create Global Firewall Rule allowing ingress HTTP and HTTPS traffic
echo "Creating firewall rules for TCP ports 80 and 443..."
gcloud compute firewall-rules create xray-allow-http-https \
    --project="$PROJECT_ID" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:80,tcp:443 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=xray-server || echo "Firewall rule already exists. Skipping..."

# Create Always-Free eligible e2-micro instance
echo "Provisioning Always-Free eligible e2-micro VM in $ZONE..."
gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT_ID" \
    --zone="$ZONE" \
    --machine-type=e2-micro \
    --network-interface=network-tier=STANDARD,subnet=default \
    --metadata-from-file=startup-script=startup.sh \
    --tags=xray-server \
    --image-family=ubuntu-2204-lts \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=10GB \
    --boot-disk-type=pd-standard \
    --quiet

echo "=========================================================="
echo "Deployment initiated successfully!"
echo "The startup script is now running on the VM to configure BBR, Nginx, and Cloudflare."
echo "Please wait while the configuration completes (usually takes 2-4 minutes)..."
echo "=========================================================="

# Polling for the subscription URL
MAX_RETRIES=30
RETRY_COUNT=0
SUB_URL=""

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    echo "Polling for your live subscription link (Attempt $((RETRY_COUNT+1))/$MAX_RETRIES)..."
    
    # Try reading the subscription URL via SSH
    SUB_URL=$(gcloud compute ssh "$INSTANCE_NAME" \
        --zone="$ZONE" \
        --project="$PROJECT_ID" \
        --quiet \
        --command="sudo cat /root/subscription_url.txt" 2>/dev/null | tr -d '\r' || true)
    
    if [[ "$SUB_URL" == https://*.trycloudflare.com/sub/ ]]; then
        break
    fi
    
    sleep 10
    RETRY_COUNT=$((RETRY_COUNT+1))
done

echo "=========================================================="
if [[ "$SUB_URL" == https://*.trycloudflare.com/sub/ ]]; then
    echo "🎉 DEPLOYMENT COMPLETE! 🎉"
    echo "Your v2box subscription link is ready to load:"
    echo "👉 $SUB_URL"
    echo "=========================================================="
else
    echo "Deployment is taking longer than expected to complete."
    echo "You can check the live boot configuration logs on the VM by running:"
    echo "gcloud compute ssh $INSTANCE_NAME --zone=$ZONE --command=\"sudo journalctl -u google-startup-scripts.service -f\""
    echo "=========================================================="
fi
