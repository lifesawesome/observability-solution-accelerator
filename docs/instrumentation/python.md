# Python Instrumentation Guide

Instrument Python applications with OpenTelemetry and Azure Monitor.

## Prerequisites

- Python 3.8+
- Application Insights connection string from Terraform output

## Option 1: Azure Monitor OpenTelemetry Distro (Recommended)

```bash
pip install azure-monitor-opentelemetry
```

### Django

```python
# settings.py or wsgi.py — configure BEFORE app starts
from azure.monitor.opentelemetry import configure_azure_monitor

configure_azure_monitor(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
)
```

### Flask

```python
from flask import Flask
from azure.monitor.opentelemetry import configure_azure_monitor

configure_azure_monitor(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
)

app = Flask(__name__)

@app.route("/")
def hello():
    return "OK"
```

### FastAPI

```python
from fastapi import FastAPI
from azure.monitor.opentelemetry import configure_azure_monitor

configure_azure_monitor(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
)

app = FastAPI()

@app.get("/")
async def root():
    return {"status": "ok"}
```

## Option 2: Manual OpenTelemetry Setup

```bash
pip install opentelemetry-sdk \
    opentelemetry-instrumentation-flask \
    opentelemetry-instrumentation-requests \
    opentelemetry-instrumentation-psycopg2 \
    azure-monitor-opentelemetry-exporter
```

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from azure.monitor.opentelemetry.exporter import AzureMonitorTraceExporter
import os

# Configure tracer
tracer_provider = TracerProvider()
exporter = AzureMonitorTraceExporter(
    connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"]
)
tracer_provider.add_span_processor(BatchSpanProcessor(exporter))
trace.set_tracer_provider(tracer_provider)
```

## Custom Spans

```python
from opentelemetry import trace

tracer = trace.get_tracer("my-python-app")

def process_order(order_id: str):
    with tracer.start_as_current_span("process_order") as span:
        span.set_attribute("order.id", order_id)
        # ... business logic
```

## Custom Metrics

```python
from opentelemetry import metrics

meter = metrics.get_meter("my-python-app")
order_counter = meter.create_counter(
    "orders.processed",
    description="Number of orders processed",
)

def process_order(order_id: str):
    # ... logic
    order_counter.add(1, {"order.status": "completed"})
```

## Logging Integration

```python
import logging
from opentelemetry.sdk._logs import LoggerProvider
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from azure.monitor.opentelemetry.exporter import AzureMonitorLogExporter

logger_provider = LoggerProvider()
logger_provider.add_log_record_processor(
    BatchLogRecordProcessor(
        AzureMonitorLogExporter(
            connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"]
        )
    )
)

# Standard Python logging will be captured
logger = logging.getLogger(__name__)
logger.warning("Order processing delayed", extra={"order_id": "12345"})
```

## Dockerfile Example

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
ENV APPLICATIONINSIGHTS_CONNECTION_STRING=""
CMD ["gunicorn", "app:app", "--bind", "0.0.0.0:8000"]
```

## Verification

1. Application Insights → Live Metrics
2. Transaction Search → filter by cloud role name
3. KQL: `AppRequests | where AppRoleName == 'my-python-app' | take 10`
4. KQL: `AppTraces | where AppRoleName == 'my-python-app' | take 10`
