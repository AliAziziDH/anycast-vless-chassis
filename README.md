# 🌩️ Anycast VLESS-WS Chassis (Melli-Shekan / ملی‌شکن)

This repository provides a **high-performance, secure, and resilient VLESS-over-WebSocket (VLESS-WS) VPN chassis** fronted by Nginx and routed through Cloudflare's Anycast CDN back to an Always-Free Google Cloud VM.

Designed with love and solidarity, this is a **gift for my fellow Iranian friends** who are navigating an increasingly restricted internet. 💚🤍❤️

---

## 🚀 Why This is Lightyears Ahead of Paid VPNs in Iran

Most commercial VPN services in Iran sell shared, easily blockable configurations on heavily congested servers. They use outdated protocols that are trivial for ISP Deep Packet Inspection (DPI) platforms to flag and block within hours.

This chassis is built on a **fully optimized, low-latency CDN fronting architecture**:
*   **Google BBR Congestion Control:** Implements Google's Bottleneck Bandwidth and RTT (BBR) algorithm to maintain high throughput and prevent packet-loss speed drops on highly unstable international transit lines.
*   **Zero Nginx Proxy Buffering:** WebSocket proxy buffering is completely disabled to eliminate frame delays, delivering real-time, low-latency routing.
*   **Standard HTTPS Port 443:** Blends in perfectly with regular encrypted web traffic, evading port-specific ISP throttling.
*   **Decentralized Clean IPs:** Utilizing Cloudflare's Anycast network, your traffic handshakes with local clean edge nodes, protecting your private exit IP from being scanned or banned.

---

## 🔒 The 50% Withheld Policy (Safety First)

To prevent automated censorship systems from scanning this codebase and building signature matches to block our active connections, **we have withheld approximately 50% of our private routing and SNI spoofing tricks**. 

However, this repo is a **fully modular, customizable chassis**. To get maximum performance:
1.  **Fork this repository.**
2.  Run a clean IP scanner (such as [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) or [CrimsonCF](https://github.com/amir0zx/CrimsonCF)) from your phone or computer.
3.  Replace the placeholder Anycast CDN IPs in your configuration with the fastest scanned IPs for your specific ISP (MCI, Irancell, Shatel, etc.).
4.  Forking allows you to customize and expand on this foundation with your own rules!

---

## 🛠️ Step-by-Step Deployment (GCP Always Free Tier)

You can host this entire setup on Google Cloud Platform for **$0/month** by leveraging GCP's Always Free Tier!

### 1. Prerequisites
*   A Google Cloud account (new accounts receive $300 in free credits).
*   A GitHub account to fork this repository.

### 2. Launching the Server
Open your **Google Cloud Shell** and run these simple commands:

```bash
# Clone your forked repository
git clone https://github.com/YOUR_GITHUB_USERNAME/anycast-vless-chassis.git
cd anycast-vless-chassis

# Make the deploy script executable
chmod +x deploy_gcp.sh

# Run the deployment (it automatically sets up firewall rules and provisions an e2-micro VM in US-Central)
./deploy_gcp.sh
```

The script will configure your VM, establish a secure Cloudflare Tunnel, set up Nginx, and output a **v2box-compatible subscription link** automatically!

---

## 📊 How to Monitor Your Bandwidth & Free Tier Limits

To help you track active connections, prevent GCP Always Free tier overages, and view Cloudflare edge metrics, we provide a sanitized telemetry tool.

If you have forked this repository and deployed the chassis, simply run the following command on your server to view a beautiful, non-interactive terminal summary:

```bash
./bin/vpn-stats
```

This tool displays:
*   **Total Bandwidth Consumed (in GB)**: Parsed safely from your Nginx access logs.
*   **Active WebSocket Connections**: Queried directly from the local Nginx stub_status.
*   **Live BBR Congestion Stats**: Summarized metrics (like bandwidth and mRTT) from active established connections.

---

## 🔗 Useful Reference Repositories

This base chassis integrates perfectly with the finest open-source diagnostic and scanning tools built by the digital resilience community:
*   [MortezaBashsiz/CFScanner](https://github.com/MortezaBashsiz/CFScanner) - The legendary Cloudflare IP scanner.
*   [XIU2/CloudflareSpeedTest](https://github.com/XIU2/CloudflareSpeedTest) - Fast, lightweight CDN edge speed tester.
*   [amir0zx/CrimsonCF](https://github.com/amir0zx/CrimsonCF) - Beautiful Layer 4 TCP scanner web app.
*   [payeh/IPCleanScanner](https://github.com/payeh/IPCleanScanner) - Clean IP scanner and tester for v2rayN.
*   [bia-pain-bache/BPB-Warp-Scanner](https://github.com/bia-pain-bache/BPB-Warp-Scanner) - Highly customizable Warp endpoint scanner using Xray-core.

---

*Made with love, fail-fast engineering, and reverse-engineering grit. Let's keep the web open.* 🕊️
