# Azure Policy Initiative Module

Assigns Azure Policy for "Monitor Everything" enforcement.

## Policies Assigned

| Policy | Target | Effect |
|--------|--------|--------|
| Deploy AMA on Windows VMs | Azure VMs | DeployIfNotExists |
| Deploy AMA on Linux VMs | Azure VMs | DeployIfNotExists |
| Deploy AMA on Arc Windows | Arc-enabled servers | DeployIfNotExists |
| Deploy AMA on Arc Linux | Arc-enabled servers | DeployIfNotExists |
| Associate Windows DCR | All Windows VMs | DeployIfNotExists |
| Associate Linux DCR | All Linux VMs | DeployIfNotExists |

## Prerequisites

- The executing identity needs `Resource Policy Contributor` role at the subscription level
- Policy assignments use system-assigned managed identity for remediation
