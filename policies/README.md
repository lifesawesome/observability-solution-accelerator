# Azure Policy Definitions

Custom and built-in Azure Policy definitions for the "Monitor Everything" initiative.

## Policy Assignments (via Terraform)

The `infra/modules/policy-initiative/` Terraform module assigns the following built-in policies:

| Policy | Target | Effect |
|--------|--------|--------|
| Deploy AMA on Windows VMs | `Microsoft.Compute/virtualMachines` (Windows) | DeployIfNotExists |
| Deploy AMA on Linux VMs | `Microsoft.Compute/virtualMachines` (Linux) | DeployIfNotExists |
| Deploy AMA on Arc Windows servers | `Microsoft.HybridCompute/machines` (Windows) | DeployIfNotExists |
| Deploy AMA on Arc Linux servers | `Microsoft.HybridCompute/machines` (Linux) | DeployIfNotExists |
| Associate Windows DCR | VMs with AMA | DeployIfNotExists |
| Associate Linux DCR | VMs with AMA | DeployIfNotExists |

## Custom Policy Definitions

| Policy | Description | Status |
|--------|-------------|--------|
| `require-diagnostic-settings.json` | Ensure all supported resources have diagnostic settings pointing to LA workspace | ✅ Implemented |
| `deny-vm-without-ama.json` | Block VM creation without AMA extension after rollout stabilizes | ✅ Implemented |
| `require-app-insights.json` | App Services must have App Insights enabled | ✅ Implemented |
| `enforce-nsg-flow-logs.json` | All NSGs must have flow logs enabled | ✅ Implemented |
| `require-arc-enrollment.json` | On-prem servers must be Arc-connected within 30 days of discovery | ✅ Implemented |

## Rollout Strategy

1. **Audit mode** — deploy policies in audit-only first to measure compliance gap
2. **Remediation** — run remediation tasks for existing non-compliant resources
3. **Enforce** — switch to `DeployIfNotExists` / `Deny` after stabilization
4. **Exceptions** — use policy exemptions for known exclusions (e.g., ephemeral VMs)
