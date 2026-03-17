# Automation Runbooks

Azure Automation runbooks for L0/L1 self-healing actions triggered by alert rules.

## Planned Runbooks

| Runbook | Trigger | Action | Status |
|---------|---------|--------|--------|
| `Restart-WindowsService.ps1` | Service stopped alert | Restart the specified Windows service via Run Command | Planned |
| `Clear-DiskSpace.ps1` | Disk > 90% alert | Delete temp files, compress old logs | Planned |
| `Restart-VM.ps1` | Heartbeat lost > 15 min | Graceful restart via `Restart-AzVM` | Planned |
| `Scale-UpVM.ps1` | CPU > 95% for 30 min | Resize VM to next SKU tier | Planned |
| `Rotate-Secret.ps1` | Key Vault expiry warning | Generate new secret, update Key Vault | Planned |

## Architecture

```
Alert Rule → Action Group (automation) → Azure Automation Webhook → Runbook
                                                                      │
                                                                      ▼
                                                               Target VM / Resource
                                                               (via system-assigned MI)
```

## Implementation Notes

- Runbooks use PowerShell 7.2+
- Authentication via Automation Account system-assigned managed identity
- Hybrid Runbook Worker for on-prem targets (via Arc)
- All runbooks log execution results back to Log Analytics via `Write-Output` → Automation Logs
- ServiceNow incident is updated with remediation result via Logic App callback
