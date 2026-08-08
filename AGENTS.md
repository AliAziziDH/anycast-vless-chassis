# 🤖 AI Agent Onboarding Manual

Welcome to the `anycast-vless-chassis` repository. This document serves as the definitive onboarding manual for any AI agent working on this codebase.

## 🛠️ Setup Commands

When working in a clean VM or a new environment, use the following commands to configure dependencies and run syntax/lint checks on our shell scripts:

```bash
# Ensure bash is available
sudo apt-get update && sudo apt-get install -y bash

# Run lint checks on our primary shell scripts
bash -n startup.sh
bash -n deploy_gcp.sh
```

## 🕸️ Network Design Constraints

Our architecture is extremely sensitive to latency and strict routing configurations to evade DPI platforms effectively. You must adhere to the following network design constraints strictly:

1. **Nginx Proxy Buffering**: Nginx proxy buffering MUST be disabled to eliminate frame delays and provide real-time, low-latency WebSocket routing. You must ensure `proxy_buffering off;` is set in all Nginx configurations.
2. **TCP_NODELAY**: You must enforce TCP_NODELAY to minimize latency for small packets.
3. **Anycast Configurations**: Anycast configurations must be strictly standardized on HTTPS Port 443. This allows the traffic to blend perfectly with regular encrypted web traffic, evading port-specific ISP throttling. Do not use non-standard ports for the Anycast CDN edge.

## 📈 Custom Telemetry & Usage Tracking

When designing custom telemetry log formats, you must adhere to strict security constraints. Under no circumstances should real visitor IPs be written without secure handling. You must always use Nginx's real-IP module variables (e.g., relying on Cloudflare's `CF-Connecting-IP` securely parsed via Nginx real-ip configuration) when recording any client IP to prevent leaking origin node IPs or exposing users.

To deploy or update the visual dashboard and telemetry API without dropping active connections, you MUST use the provided hotpatch script:

```bash
sudo ./hotpatch_monitoring.sh
```

Ensure that any custom telemetry APIs bind exclusively to `localhost` (e.g. `127.0.0.1:8080`) and are only exposed to the internet via Nginx reverse proxy with `proxy_buffering off;` and `tcp_nodelay on;`.

## 🛑 Pre-Submission Requirements

A mandatory test/lint check gate is required before submitting any pull requests.
You must verify that all syntax checks pass:

```bash
bash -n startup.sh
bash -n deploy_gcp.sh
```

Ensure these checks complete successfully without any errors before proposing your changes.
