# Copilot Instructions for Observability Solution Accelerator

## Project Context

This repository is a reusable, multi-tenant observability solution accelerator built on Azure. It uses **Terraform** (not Bicep) for all infrastructure-as-code. The target customers are enterprise energy/industrial companies with hybrid (on-prem + Azure) environments and OT/IoT workloads.

## Terraform Conventions

- **Provider**: `azurerm ~> 4.0` — always use v4 resource names and argument syntax.
- **Module structure**: Each module lives in `infra/modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`, and `README.md`.
- **Naming**: Resources follow `{customer_name}-{component}-{environment}` convention via `locals` in root `main.tf`.
- **Feature flags**: Optional modules (Sentinel, IoT Hub, Lighthouse, Network Observability) are controlled by `enable_*` boolean variables with `count` conditionals.
- **No hardcoded values**: All resource names, locations, SKUs, and configuration are driven by variables.
- **State**: Terraform state uses remote backend (Azure Storage) in production. Local state is acceptable during development.

## KQL Query Conventions

- Use workspace-scoped queries (not cross-resource by default).
- For cross-workspace queries in hub workbooks, use `workspace('<spoke-name>').TableName`.
- Always include `TimeGenerated` filters for performance.
- Use `series_decompose_anomalies` for anomaly detection, not static thresholds.
- Prefer `AppRequests` / `AppDependencies` (workspace-based) over legacy `requests` / `dependencies`.

## Azure Workbook Conventions

- Workbooks are stored as JSON in `dashboards/workbooks/`.
- Use parameterized time ranges and subscription filters.
- Every KQL query in a workbook should include a comment explaining its purpose.

## File Organization

```
infra/           → Terraform root and modules
dashboards/      → Azure Workbooks (JSON) and Power BI templates
automation/      → Runbooks and Logic App templates
policies/        → Custom Azure Policy definitions
docs/            → Architecture, playbooks, instrumentation guides
templates/       → Assessment templates for customer engagements
```

## Security Rules

- Never commit secrets, connection strings, or SAS tokens.
- Use managed identity for all Azure resource authentication.
- IoT Hub SAS policies must separate send and listen permissions.
- Lighthouse delegations use `Monitoring Reader`, `Log Analytics Reader`, `Sentinel Reader` only — no write access.
- Terraform state must be in encrypted Azure Storage with access controls.

## When Adding New Modules

1. Create `infra/modules/<name>/` with `main.tf`, `variables.tf`, `outputs.tf`, `README.md`.
2. Add a `enable_<name>` variable in `infra/variables.tf`.
3. Add the module call in `infra/main.tf` with `count` conditional.
4. Add outputs in `infra/outputs.tf`.
5. Update `docs/architecture/overview.md` with the new module in the module map table.
