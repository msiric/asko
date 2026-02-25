# Tailscale Setup

Tailscale provides secure remote access to your asko instance without exposing any ports to the internet.

## Install on the Server (Beelink)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up --ssh --accept-routes
```

The `--ssh` flag enables Tailscale SSH, so you can access the server without opening port 22.

## Install on Client Devices

Install Tailscale on every device that needs access:

- **iPhone/Android**: Download from App Store / Play Store
- **Mac/Windows/Linux**: https://tailscale.com/download
- **Browser**: Use the Tailscale admin console at https://login.tailscale.com

Once connected, all devices can reach the Beelink via its Tailscale IP (e.g., `100.x.y.z`).

## DNS Setup

### Option A: Direct IP Access

Access services directly:

```
http://100.x.y.z:80    → Caddy (routes to all services)
```

### Option B: MagicDNS

Tailscale assigns a hostname like `beelink-asko.tailnet-xxxx.ts.net`. Use this in your browser.

### Option C: Custom DNS (Recommended)

If you have PiHole or another DNS server, add custom records:

```
chat.asko.local    → 100.x.y.z   (Tailscale IP of Beelink)
n8n.asko.local     → 100.x.y.z
ai.asko.local      → 100.x.y.z
agent.asko.local   → 100.x.y.z
```

This gives you clean URLs: `http://chat.asko.local`

## Access Control Lists (ACLs)

Configure in the [Tailscale admin console](https://login.tailscale.com/admin/acls):

```jsonc
{
  "acls": [
    // Admin: full access
    {
      "action": "accept",
      "src": ["your-email@example.com"],
      "dst": ["tag:asko:*"]
    },

    // Girlfriend: chat and agent only (no n8n, no litellm admin)
    {
      "action": "accept",
      "src": ["girlfriend@example.com"],
      "dst": ["tag:asko:80", "tag:asko:443"]
    },

    // Family: same as girlfriend
    {
      "action": "accept",
      "src": ["group:family"],
      "dst": ["tag:asko:80", "tag:asko:443"]
    }
  ],
  "tagOwners": {
    "tag:asko": ["your-email@example.com"]
  },
  "groups": {
    "group:family": [
      "family-member1@example.com",
      "family-member2@example.com"
    ]
  }
}
```

With this config, family members can access the web UI (chat, agent) but not n8n or LiteLLM admin panels. Caddy can further restrict which subdomains are accessible based on source IP.

## Connecting Prague and Split

If you have a home lab in Split (like the existing prosko/kisko setup), you can mesh both locations:

1. Install Tailscale on the Split server
2. Both servers appear on the same Tailscale network
3. Services can communicate across locations via Tailscale IPs
4. Use `--advertise-routes` to expose local subnets if needed

## Troubleshooting

```bash
# Check Tailscale status
tailscale status

# Check if the server is reachable
tailscale ping beelink-asko

# Check firewall
sudo ufw status
```
