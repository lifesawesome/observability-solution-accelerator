# Logic App Templates

Logic Apps for bidirectional ServiceNow integration and orchestration workflows.

## Planned Templates

| Template | Trigger | Flow | Status |
|----------|---------|------|--------|
| `alert-to-servicenow-incident.json` | HTTP webhook (Action Group) | Parse alert → Create ServiceNow incident → Post Teams notification | Planned |
| `servicenow-incident-update-sync.json` | ServiceNow webhook | Incident state change → Update Azure alert state | Planned |
| `cmdb-sync-from-resource-graph.json` | Recurrence (daily) | Azure Resource Graph query → Upsert ServiceNow CMDB CIs | Planned |
| `runbook-result-to-servicenow.json` | Automation webhook | Runbook completion → Update ServiceNow work notes | Planned |

## Architecture

```
                    ┌─────────────────────┐
                    │   Azure Monitor     │
                    │   Alert Rules       │
                    └────────┬────────────┘
                             │ webhook
                             ▼
                    ┌─────────────────────┐
                    │   Logic App         │
                    │   (HTTP trigger)    │
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌────────────┐  ┌───────────┐  ┌────────────┐
     │ ServiceNow │  │   Teams   │  │ Automation │
     │ (incident) │  │ (notify)  │  │ (runbook)  │
     └────────────┘  └───────────┘  └────────────┘
```

## Implementation Notes

- Logic Apps use managed identity for Azure resource access
- ServiceNow connector uses OAuth 2.0 (not basic auth)
- All Logic Apps deployed via ARM/Terraform `azurerm_logic_app_workflow`
- Alert payload schema follows Azure Monitor Common Alert Schema v2
