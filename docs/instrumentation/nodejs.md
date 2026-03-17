# Node.js Instrumentation Guide

Instrument Node.js applications with OpenTelemetry and Azure Monitor.

## Prerequisites

- Node.js 14+ (18+ recommended)
- Application Insights connection string from Terraform output

## Option 1: Azure Monitor OpenTelemetry Distro (Recommended)

```bash
npm install @azure/monitor-opentelemetry
```

### Setup (must be first import)

Create `instrumentation.ts` (or `.js`):

```typescript
import { useAzureMonitor } from "@azure/monitor-opentelemetry";

useAzureMonitor({
  azureMonitorExporterOptions: {
    connectionString: process.env.APPLICATIONINSIGHTS_CONNECTION_STRING,
  },
  instrumentationOptions: {
    http: { enabled: true },
    azureSdk: { enabled: true },
    mongoDb: { enabled: true },
    mySql: { enabled: true },
    postgreSql: { enabled: true },
    redis: { enabled: true },
  },
});
```

### Entry point

```typescript
// instrumentation must be imported BEFORE anything else
import "./instrumentation";
import express from "express";

const app = express();
app.get("/", (req, res) => res.send("OK"));
app.listen(3000);
```

Or use Node.js `--require`:

```bash
node --require ./instrumentation.js app.js
```

## Option 2: Manual OpenTelemetry Setup

```bash
npm install @opentelemetry/sdk-node \
  @opentelemetry/auto-instrumentations-node \
  @azure/monitor-opentelemetry-exporter
```

```typescript
import { NodeSDK } from "@opentelemetry/sdk-node";
import { getNodeAutoInstrumentations } from "@opentelemetry/auto-instrumentations-node";
import { AzureMonitorTraceExporter } from "@azure/monitor-opentelemetry-exporter";
import { AzureMonitorLogExporter } from "@azure/monitor-opentelemetry-exporter";

const connectionString = process.env.APPLICATIONINSIGHTS_CONNECTION_STRING;

const sdk = new NodeSDK({
  traceExporter: new AzureMonitorTraceExporter({ connectionString }),
  instrumentations: [getNodeAutoInstrumentations()],
});

sdk.start();
```

## Custom Spans

```typescript
import { trace } from "@opentelemetry/api";

const tracer = trace.getTracer("my-node-app");

async function processOrder(orderId: string) {
  return tracer.startActiveSpan("processOrder", async (span) => {
    span.setAttribute("order.id", orderId);
    try {
      // ... business logic
    } finally {
      span.end();
    }
  });
}
```

## Custom Metrics

```typescript
import { metrics } from "@opentelemetry/api";

const meter = metrics.getMeter("my-node-app");
const orderCounter = meter.createCounter("orders.processed", {
  description: "Number of orders processed",
});

function processOrder(orderId: string) {
  // ... logic
  orderCounter.add(1, { "order.status": "completed" });
}
```

## Dockerfile Example

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --production
COPY . .
ENV APPLICATIONINSIGHTS_CONNECTION_STRING=""
CMD ["node", "--require", "./instrumentation.js", "app.js"]
```

## Verification

1. Application Insights → Live Metrics
2. Transaction Search → filter by cloud role name
3. KQL: `AppRequests | where AppRoleName == 'my-node-app' | take 10`
4. KQL: `AppDependencies | where AppRoleName == 'my-node-app' | summarize count() by Type`
