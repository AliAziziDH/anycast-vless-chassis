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
2. **Anycast Configurations**: Anycast configurations must be strictly standardized on HTTPS Port 443. This allows the traffic to blend perfectly with regular encrypted web traffic, evading port-specific ISP throttling. Do not use non-standard ports for the Anycast CDN edge.

## 🛑 Pre-Submission Requirements

A mandatory test/lint check gate is required before submitting any pull requests.
You must verify that all syntax checks pass:

```bash
bash -n startup.sh
bash -n deploy_gcp.sh
```

Ensure these checks complete successfully without any errors before proposing your changes.
