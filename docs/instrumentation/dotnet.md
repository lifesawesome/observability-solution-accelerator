# .NET Instrumentation Guide

Instrument .NET applications with OpenTelemetry and Azure Monitor.

## Prerequisites

- .NET 6.0+ (or .NET Framework 4.6.2+ for legacy)
- Application Insights connection string from Terraform output

## Option 1: Azure Monitor OpenTelemetry Distro (Recommended)

The Azure Monitor distro wraps OpenTelemetry and auto-configures the Azure exporter.

### Install NuGet Package

```bash
dotnet add package Azure.Monitor.OpenTelemetry.AspNetCore
```

### Configure in `Program.cs`

```csharp
using Azure.Monitor.OpenTelemetry.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Add Azure Monitor OpenTelemetry
builder.Services.AddOpenTelemetry().UseAzureMonitor(options =>
{
    options.ConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
});

var app = builder.Build();
app.Run();
```

### Set the Connection String

Use environment variable (preferred) or `appsettings.json`:

```bash
# Environment variable
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=...;IngestionEndpoint=..."
```

```json
// appsettings.json
{
  "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=...;IngestionEndpoint=..."
}
```

## Option 2: Manual OpenTelemetry Setup

For more control over which instrumentations are included.

```bash
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Instrumentation.SqlClient
dotnet add package Azure.Monitor.OpenTelemetry.Exporter
```

```csharp
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using OpenTelemetry.Logs;
using Azure.Monitor.OpenTelemetry.Exporter;

var builder = WebApplication.CreateBuilder(args);
var connStr = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];

builder.Services.AddOpenTelemetry()
    .ConfigureResource(r => r.AddService("my-dotnet-app"))
    .WithTracing(t => t
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSqlClientInstrumentation(o => o.SetDbStatementForText = true)
        .AddAzureMonitorTraceExporter(o => o.ConnectionString = connStr))
    .WithMetrics(m => m
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddAzureMonitorMetricExporter(o => o.ConnectionString = connStr));

builder.Logging.AddOpenTelemetry(l =>
{
    l.AddAzureMonitorLogExporter(o => o.ConnectionString = connStr);
});

var app = builder.Build();
app.Run();
```

## Custom Telemetry

```csharp
using System.Diagnostics;

// Create an ActivitySource for custom spans
private static readonly ActivitySource s_source = new("MyApp.CustomOperations");

public async Task ProcessOrderAsync(Order order)
{
    using var activity = s_source.StartActivity("ProcessOrder");
    activity?.SetTag("order.id", order.Id);
    activity?.SetTag("order.total", order.Total);

    // ... business logic
}
```

## Verification

After deployment, verify telemetry in Azure Portal:

1. Go to Application Insights resource
2. Check **Live Metrics** for real-time data
3. Check **Transaction Search** for requests/dependencies
4. Check **Application Map** for service topology
5. Run KQL: `AppRequests | take 10`
