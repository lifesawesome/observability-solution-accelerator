# Fabric Workspace Module

Microsoft Fabric workspace configuration for OT/IoT analytics.

> **Note**: Fabric resources are not yet fully supported by the AzureRM Terraform provider.
> This module provides guidance and CLI/REST scripts for manual or pipeline-based setup.

## What To Deploy

| Resource | Purpose |
|----------|---------|
| Fabric Workspace | Container for all OT analytics assets |
| KQL Database (Eventhouse) | Real-time queries over streaming IoT telemetry |
| Lakehouse | Historical OT data for ML model training |
| Data Activator (Reflex) | Pattern-based proactive triggers (no static alerts) |

## Setup via CLI / REST

```bash
# Create Fabric workspace (requires Fabric capacity)
# Use the Fabric REST API or Power BI Admin portal

# Connect Event Hub → KQL Database
# In Fabric portal: Eventhouse > Get Data > Event Hub > use connection string from iot-hub module output

# Create Lakehouse
# In Fabric portal: New > Lakehouse > configure shortcut from KQL Database for historical partitioning
```

## Data Flow

```
IoT Hub → Event Hubs → Fabric KQL Database (real-time, hot path)
                      → Fabric Lakehouse (batch, cold path)
                      → Data Activator (proactive triggers)
                      → Power BI (dashboards)
```

## Terraform Support Roadmap

When the `azurerm` or `fabric` provider adds Fabric workspace resources, this module
will be updated with full Terraform configuration. Track progress:
- https://github.com/hashicorp/terraform-provider-azurerm/issues
- https://github.com/microsoft/terraform-provider-fabric
