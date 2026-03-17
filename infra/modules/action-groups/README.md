# Action Groups Module

Notification channels for alert routing.

## Groups Created

| Group | Purpose | Channels |
|-------|---------|----------|
| Critical | P1/P2 alerts | Email + ServiceNow webhook |
| Warning | P3/P4 alerts | Email only |
| Automation | L0 self-healing | Email (+ add runbook webhooks post-deploy) |
