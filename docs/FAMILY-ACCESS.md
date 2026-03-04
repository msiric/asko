# Setting Up Family Access

This guide walks through onboarding family members to use asko.

## What Family Members Get

| Service | How They Access It | What They Can Do |
|---------|-------------------|------------------|
| **Open WebUI** | Browser (`chat.asko.local`) | Chat with AI models, upload documents |
| **Telegram Bot** | Telegram (via AI agent) | Send messages, get AI responses |
| **WhatsApp Bot** | WhatsApp (via WAHA) | Send messages, get AI responses |

Family members do **not** get access to n8n (workflow editor) or LiteLLM admin.

## Step 1: Install Tailscale

Each family member needs Tailscale on their device:

1. Download from https://tailscale.com/download
2. Sign in (invite them to your Tailscale network via the admin console)
3. Once connected, they can reach the Beelink

## Step 2: Create Open WebUI Accounts

1. Log into Open WebUI as admin: `http://chat.asko.local`
2. Go to **Admin Panel** (top-right menu)
3. Click **Add User**
4. Enter their name, email, and a password
5. Set role to **User** (not Admin)
6. Share the credentials with them

Each user gets:
- Private conversation history
- Access to all configured models (local + cloud)
- Ability to upload documents for RAG
- Personal settings and preferences

## Step 3: Set Up Telegram Bot (Optional)

Telegram access is configured separately via your AI agent (e.g., OpenClaw). See your agent's documentation for setup instructions.

## Step 4: Set Up WhatsApp (via WAHA)

1. Open the WAHA dashboard (accessible to admin only)
2. Scan the QR code with your WhatsApp to pair
3. Family members message the paired WhatsApp number
4. n8n routes messages through the AI assistant workflow

## Privacy Between Users

- **Open WebUI**: Each user's chat history is completely private. Other users (including admin) cannot see conversations through the UI.
- **Telegram**: Configured separately via your AI agent. Each user gets an isolated session.
- **WhatsApp**: Messages are processed per-sender by n8n.

The admin can see system logs and database contents, but normal usage is private per user.

## Setting Up Shared Workflows

For shared use cases (trip planning, family grocery list, etc.):

1. **Telegram Group**: Create a Telegram group, add the bot. Everyone in the group shares the conversation context.
2. **Shared Open WebUI workspace**: Currently not supported per-user in community edition. Use a dedicated "Family" account that everyone shares for collaborative chats.
3. **n8n webhooks**: Build specific workflows (e.g., `/plan-trip`) that anyone can trigger via the bot.

## Troubleshooting

**"Can't reach chat.asko.local"**
- Check Tailscale is connected on their device: look for the Tailscale icon
- Try the direct IP instead: `http://100.x.y.z`
- Check DNS is configured (see [TAILSCALE.md](TAILSCALE.md))

**"Telegram bot not responding"**
- Telegram is managed by your AI agent (outside this Docker stack). Check your agent's logs and status.

**"AI responses are slow"**
- Local models run on CPU — expect 5-15 seconds for responses
- Longer prompts take proportionally longer
- Consider switching to a cloud model for complex queries
