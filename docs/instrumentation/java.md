# Java Instrumentation Guide

Instrument Java applications with OpenTelemetry and Azure Monitor.

## Prerequisites

- Java 8+ (Java 11+ recommended)
- Application Insights connection string from Terraform output

## Option 1: Auto-Instrumentation Agent (Recommended)

Zero-code-change approach using the Azure Monitor OpenTelemetry Java agent.

### Download the Agent

```bash
curl -L -o applicationinsights-agent.jar \
  https://github.com/microsoft/ApplicationInsights-Java/releases/latest/download/applicationinsights-agent.jar
```

### Configure `applicationinsights.json`

Create `applicationinsights.json` in the same directory as the agent JAR:

```json
{
  "connectionString": "InstrumentationKey=...;IngestionEndpoint=...",
  "role": {
    "name": "my-java-app"
  },
  "sampling": {
    "percentage": 100
  },
  "preview": {
    "sampling": {
      "overrides": [
        {
          "telemetryType": "dependency",
          "attributes": [
            { "key": "http.url", "value": "/health", "matchType": "contains" }
          ],
          "percentage": 0
        }
      ]
    }
  }
}
```

### Attach to JVM

```bash
java -javaagent:applicationinsights-agent.jar -jar myapp.jar
```

Or in a Dockerfile:

```dockerfile
FROM eclipse-temurin:17-jre
COPY applicationinsights-agent.jar /opt/agent/
COPY applicationinsights.json /opt/agent/
COPY myapp.jar /opt/app/
ENTRYPOINT ["java", "-javaagent:/opt/agent/applicationinsights-agent.jar", "-jar", "/opt/app/myapp.jar"]
```

## Option 2: Manual OpenTelemetry SDK

For Spring Boot or when you need custom spans.

### Maven Dependencies

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>io.opentelemetry</groupId>
      <artifactId>opentelemetry-bom</artifactId>
      <version>1.36.0</version>
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-api</artifactId>
  </dependency>
  <dependency>
    <groupId>io.opentelemetry</groupId>
    <artifactId>opentelemetry-sdk</artifactId>
  </dependency>
  <dependency>
    <groupId>com.azure</groupId>
    <artifactId>azure-monitor-opentelemetry-exporter</artifactId>
    <version>1.0.0-beta.21</version>
  </dependency>
</dependencies>
```

### Custom Spans

```java
import io.opentelemetry.api.GlobalOpenTelemetry;
import io.opentelemetry.api.trace.Span;
import io.opentelemetry.api.trace.Tracer;

public class OrderService {
    private static final Tracer tracer =
        GlobalOpenTelemetry.getTracer("com.myapp.orders");

    public void processOrder(String orderId) {
        Span span = tracer.spanBuilder("processOrder").startSpan();
        try (var scope = span.makeCurrent()) {
            span.setAttribute("order.id", orderId);
            // ... business logic
        } finally {
            span.end();
        }
    }
}
```

## Environment Variable Configuration

```bash
export APPLICATIONINSIGHTS_CONNECTION_STRING="InstrumentationKey=...;IngestionEndpoint=..."
```

## Verification

1. Application Insights → Live Metrics
2. Transaction Search → filter by role name
3. Application Map → verify service dependencies
4. KQL: `AppRequests | where AppRoleName == 'my-java-app' | take 10`
