# Network Observability Module

Deploys network monitoring infrastructure: Network Watcher, flow log storage, and Traffic Analytics foundation.

## What It Deploys
- Network Watcher (regional)
- Storage Account for NSG flow logs (TLS 1.2, LRS, 30d retention)

## Post-Deployment

NSG Flow Logs must be enabled per-NSG after deployment. Use Azure Policy or CLI:

```bash
az network watcher flow-log create \
  --resource-group <rg> \
  --nsg <nsg-name> \
  --storage-account <storage-id> \
  --workspace <workspace-id> \
  --enabled true \
  --traffic-analytics true
```
