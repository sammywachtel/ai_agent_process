# BEADS Server Deployment

Deploy a Dolt SQL server on GCE e2-micro for centralized BEADS state tracking.

## What It Creates

- **GCE e2-micro VM** (~$7/month) running Ubuntu 22.04
- **Dolt SQL server** listening on port 3307 (MySQL-compatible)
- **Firewall rule** allowing connections from your specified CIDR
- **Static external IP** so `quality-config.json` stays stable across reboots
- **systemd service** that auto-starts Dolt on boot

## Prerequisites

- `gcloud` CLI installed and authenticated (`gcloud auth login`)
- A GCP project with billing enabled
- If you need a new project: `gcloud projects create my-beads-project --name="BEADS Server"`
  Then enable billing: https://console.cloud.google.com/billing

## Usage

```bash
# Interactive setup (prompts for everything)
./setup.sh

# Non-interactive
./setup.sh --project my-project --password mySecurePass123 --allow-cidr 0.0.0.0/0

# Tear down everything
./teardown.sh
```

## After Deployment

The script outputs a `quality-config.json` snippet. Add it to each project that should use this server:

```json
{
  "beads": {
    "enabled": true,
    "server": {
      "host": "34.xxx.xxx.xxx",
      "port": 3307,
      "user": "beads"
    }
  }
}
```

Set the password as an environment variable (don't put it in config files):

```bash
export BEADS_DOLT_PASSWORD=yourPasswordHere
```

## Cost

| Resource | Monthly Cost |
|----------|-------------|
| e2-micro VM | ~$6.11 (or free if within free tier) |
| 10GB standard disk | ~$0.40 |
| Static IP (while attached) | Free |
| **Total** | **~$7/month** |

## Architecture

```
┌─────────────────────────────────────┐
│  GCE e2-micro (beads-dolt-server)   │
│                                     │
│  Ubuntu 22.04                       │
│  Dolt SQL Server :3307              │
│  systemd managed, auto-restart      │
│  10GB persistent disk               │
└──────────────────┬──────────────────┘
                   │
     ┌─────────────┼─────────────┐
     │             │             │
┌────┴────┐  ┌─────┴────┐  ┌────┴────┐
│ Dev A   │  │ Dev B    │  │ CI/CD   │
│ bd CLI  │  │ bd CLI   │  │ bd CLI  │
│ laptop  │  │ container│  │ agent   │
└─────────┘  └──────────┘  └─────────┘

All clients read beads.server from quality-config.json
```

## Files

| File | Purpose | Committed? |
|------|---------|-----------|
| `setup.sh` | Creates the GCE resources | ✅ Yes |
| `teardown.sh` | Destroys all GCE resources | ✅ Yes |
| `.beads-server-info` | Connection details (created by setup.sh) | ❌ No (gitignored) |

## Maintenance

**SSH into the server:**
```bash
source .beads-server-info
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE
```

**Check Dolt status:**
```bash
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- systemctl status dolt
```

**View Dolt logs:**
```bash
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- journalctl -u dolt -f
```

**Restart Dolt:**
```bash
gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- sudo systemctl restart dolt
```
