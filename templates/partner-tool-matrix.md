# Partner Tool Matrix

Map the customer's existing monitoring/management tools to Azure-native equivalents. Use during Phase 1 to identify consolidation opportunities and migration paths.

---

## Customer: _______________
## Date: _______________

---

## IT Infrastructure Monitoring

| Capability | Customer's Current Tool | Azure Equivalent | Migration Path | Consolidate? |
|------------|------------------------|------------------|----------------|--------------|
| Server monitoring | SCOM / Nagios / Zabbix / Datadog | Azure Monitor + AMA + DCRs | Deploy AMA, retire legacy agent | Y / N |
| Network monitoring | SolarWinds / PRTG / ThousandEyes | Network Watcher + NSG Flow Logs | Enable flow logs, migrate dashboards | Y / N |
| Patch management | WSUS / SCCM / Ivanti | Azure Update Manager | Enroll via Azure Policy | Y / N |
| Configuration mgmt | Puppet / Chef / Ansible | Azure Policy + Automanage | Shift compliance to Policy | Y / N |
| Hybrid management | Manual / VPN | Azure Arc | Project on-prem servers to ARM | Y / N |
| Log aggregation | Splunk / ELK / Graylog | Log Analytics Workspace | Migrate queries, use AMA for ingestion | Y / N |

---

## Application Performance Monitoring

| Capability | Customer's Current Tool | Azure Equivalent | Migration Path | Consolidate? |
|------------|------------------------|------------------|----------------|--------------|
| APM / tracing | New Relic / Dynatrace / AppDynamics | Application Insights + OTel | Add OTel SDK, set connection string | Y / N |
| Synthetic monitoring | Pingdom / Uptime Robot | Application Insights Availability | Configure URL ping tests | Y / N |
| Error tracking | Sentry / Rollbar | Application Insights Exceptions | Captured via OTel SDK | Y / N |
| Real User Monitoring | Google Analytics / Datadog RUM | Application Insights JavaScript SDK | Add JS snippet to pages | Y / N |
| Logging | Log4j → ELK / Splunk | App Insights + Log Analytics | OTel logging bridge | Y / N |

---

## Security & Compliance

| Capability | Customer's Current Tool | Azure Equivalent | Migration Path | Consolidate? |
|------------|------------------------|------------------|----------------|--------------|
| SIEM | Splunk ES / QRadar / ArcSight | Microsoft Sentinel | Migrate detection rules, enable connectors | Y / N |
| SOAR | Phantom / Demisto / Swimlane | Sentinel Playbooks (Logic Apps) | Rebuild automation as playbooks | Y / N |
| EDR / XDR | CrowdStrike / Carbon Black | Defender for Endpoint / M365 Defender | Deploy Defender agents | Y / N |
| Vulnerability scanning | Qualys / Nessus / Rapid7 | Defender for Cloud (CSPM) | Enable Defender plans | Y / N |
| Identity protection | Okta / Ping / on-prem AD | Entra ID Protection + Sentinel UEBA | Connect sign-in logs to Sentinel | Y / N |

---

## OT/IoT

| Capability | Customer's Current Tool | Azure Equivalent | Migration Path | Consolidate? |
|------------|------------------------|------------------|----------------|--------------|
| Device management | Proprietary / OSIsoft PI | Azure IoT Hub + IoT Edge | Register devices, deploy edge runtime | Y / N |
| OT security | Claroty / Nozomi / Dragos | Defender for IoT | Deploy agentless sensors | Y / N |
| Historian / analytics | OSIsoft PI / Honeywell PHD | Microsoft Fabric (KQL DB + Lakehouse) | Route telemetry via Event Hub | Y / N |
| Predictive maintenance | Custom / none | Azure ML + Fabric Data Activator | Train models on historical data | Y / N |
| SCADA dashboards | Wonderware / Ignition | Power BI + Fabric | Connect to KQL Database | Y / N |

---

## Workflow & Automation

| Capability | Customer's Current Tool | Azure Equivalent | Migration Path | Consolidate? |
|------------|------------------------|------------------|----------------|--------------|
| ITSM | ServiceNow / Jira SM / BMC | ServiceNow (keep) + ITSMC connector | Configure webhook integration | N/A |
| CMDB | ServiceNow CMDB / manual | ServiceNow + Resource Graph sync | Bootstrap from Azure Resource Graph | Y / N |
| Automation | Ansible / custom scripts | Azure Automation Runbooks | Migrate scripts to runbooks | Y / N |
| Orchestration | Custom / none | Logic Apps | Build workflows for incident lifecycle | Y / N |
| ChatOps | Slack / Teams (manual) | Teams + Copilot for Operations | Enable Copilot, route alerts to Teams | Y / N |

---

## Consolidation Summary

| Category | Current Tools Count | Target Azure Tools | Estimated Savings |
|----------|--------------------|--------------------|-------------------|
| IT Infrastructure | | | |
| APM | | | |
| Security | | | |
| OT/IoT | | | |
| Workflow | | | |
| **Total** | | | |

---

## Recommended Partner Engagement

| Partner | Specialization | When to Engage |
|---------|---------------|----------------|
| DXC Technology | Managed services, IT infrastructure | Phase 2 deployment at scale |
| HCL Technologies | Application modernization, cloud ops | Phase 2-3 app instrumentation |
| Customer's existing MSP | Transition planning | Phase 1 discovery |
| Azure FastTrack | Architecture review | Phase 1-2 validation |

---

## Notes

_Use this space for customer-specific observations, constraints, or decisions._
