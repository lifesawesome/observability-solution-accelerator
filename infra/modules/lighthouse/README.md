# Azure Lighthouse Module

Configures cross-tenant delegation from customer subscription to your hub MSP tenant.

## Delegated Roles

| Role | Purpose |
|------|---------|
| Monitoring Reader | Read metrics, logs, alerts in customer subscription |
| Log Analytics Reader | Run cross-workspace KQL queries |
| Microsoft Sentinel Reader | View security incidents and workbooks |

## Prerequisites

- Customer subscription owner must approve the delegation
- Hub tenant must have a service principal or security group to receive delegation
