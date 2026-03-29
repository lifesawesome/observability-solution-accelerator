#!/usr/bin/env python3
"""
Inject fake telemetry into the Observability Accelerator stack for E2E testing.
Targets: App Insights, Event Hub (IoT), and Log Analytics workspace.
"""

import json
import time
import datetime
import hashlib
import hmac
import base64
import random
import urllib.request
import urllib.error

# ============================================================================
# Configuration (from deployed resources)
# ============================================================================
APP_INSIGHTS_IKEY = "35bd9f3a-2bbd-4bab-b445-994a3774e391"
APP_INSIGHTS_ENDPOINT = "https://eastus-8.in.applicationinsights.azure.com/v2/track"

LOG_ANALYTICS_WORKSPACE_ID = "104062e0-1048-43fa-85b2-d728b3cb089b"
LOG_ANALYTICS_SHARED_KEY = "ISPAhDEWh7Ou9FWDKm6xNdGEwiu4UF1z/2GQIzPxXCGsNQrkfucIuepvyewqQX01uq1G+5pFP6dxyjR6toYYbQ=="

EVENT_HUB_NAMESPACE = "evhns-iot-obstest-obs"
EVENT_HUB_NAME = "iot-telemetry"


# ============================================================================
# 1. App Insights — Send requests, exceptions, traces, custom metrics
# ============================================================================
def send_app_insights_telemetry():
    print("\n=== App Insights: Injecting Telemetry ===")
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.%fZ")

    items = []

    # Successful requests
    for i in range(10):
        items.append({
            "name": "Microsoft.ApplicationInsights.Request",
            "time": now,
            "iKey": APP_INSIGHTS_IKEY,
            "data": {
                "baseType": "RequestData",
                "baseData": {
                    "ver": 2,
                    "id": f"req-{i:04d}",
                    "name": f"GET /api/orders/{i}",
                    "duration": f"00:00:0{random.uniform(0.1, 2.5):.1f}",
                    "responseCode": "200",
                    "success": True,
                    "url": f"https://testapp.example.com/api/orders/{i}",
                    "properties": {"environment": "e2e-test", "service": "order-api"}
                }
            }
        })

    # Failed requests (to trigger alerts)
    for i in range(5):
        items.append({
            "name": "Microsoft.ApplicationInsights.Request",
            "time": now,
            "iKey": APP_INSIGHTS_IKEY,
            "data": {
                "baseType": "RequestData",
                "baseData": {
                    "ver": 2,
                    "id": f"req-fail-{i:04d}",
                    "name": "POST /api/checkout",
                    "duration": f"00:00:0{random.uniform(3.0, 8.0):.1f}",
                    "responseCode": "500",
                    "success": False,
                    "url": "https://testapp.example.com/api/checkout",
                    "properties": {"environment": "e2e-test", "error": "DatabaseTimeout"}
                }
            }
        })

    # Exceptions
    for i in range(3):
        items.append({
            "name": "Microsoft.ApplicationInsights.Exception",
            "time": now,
            "iKey": APP_INSIGHTS_IKEY,
            "data": {
                "baseType": "ExceptionData",
                "baseData": {
                    "ver": 2,
                    "exceptions": [{
                        "id": i,
                        "typeName": ["NullReferenceException", "TimeoutException", "SqlException"][i],
                        "message": f"Fake exception #{i} for E2E testing",
                        "hasFullStack": True,
                        "stack": f"  at TestApp.Services.OrderService.Process() in OrderService.cs:line {42 + i}"
                    }],
                    "properties": {"environment": "e2e-test"}
                }
            }
        })

    # Traces
    for msg in ["Application starting up", "Order processed successfully", "Cache miss - fetching from DB",
                 "Retry attempt 1 for payment gateway", "Health check: all systems nominal"]:
        items.append({
            "name": "Microsoft.ApplicationInsights.Message",
            "time": now,
            "iKey": APP_INSIGHTS_IKEY,
            "data": {
                "baseType": "MessageData",
                "baseData": {
                    "ver": 2,
                    "message": msg,
                    "severityLevel": random.choice([0, 1, 2]),
                    "properties": {"environment": "e2e-test", "component": "order-api"}
                }
            }
        })

    # Custom metrics
    for metric_name, value in [("OrdersProcessed", 142), ("AverageLatencyMs", 234.5),
                                ("ActiveConnections", 37), ("CacheHitRatio", 0.87)]:
        items.append({
            "name": "Microsoft.ApplicationInsights.Metric",
            "time": now,
            "iKey": APP_INSIGHTS_IKEY,
            "data": {
                "baseType": "MetricData",
                "baseData": {
                    "ver": 2,
                    "metrics": [{"name": metric_name, "value": value, "count": 1}],
                    "properties": {"environment": "e2e-test"}
                }
            }
        })

    # Custom events
    for event in ["UserLogin", "OrderPlaced", "PaymentCompleted", "ItemShipped"]:
        items.append({
            "name": "Microsoft.ApplicationInsights.Event",
            "time": now,
            "iKey": APP_INSIGHTS_IKEY,
            "data": {
                "baseType": "EventData",
                "baseData": {
                    "ver": 2,
                    "name": event,
                    "properties": {"environment": "e2e-test", "userId": f"user-{random.randint(1000,9999)}"}
                }
            }
        })

    payload = json.dumps(items).encode("utf-8")
    req = urllib.request.Request(
        APP_INSIGHTS_ENDPOINT,
        data=payload,
        headers={"Content-Type": "application/json", "Accept": "application/json"},
        method="POST"
    )
    try:
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read())
        print(f"  Sent {len(items)} items -> {result.get('itemsReceived', '?')} received, "
              f"{result.get('itemsAccepted', '?')} accepted")
    except urllib.error.HTTPError as e:
        print(f"  ERROR: {e.code} - {e.read().decode()}")


# ============================================================================
# 2. Log Analytics — Send custom log data (Heartbeat + Perf counters)
# ============================================================================
def _build_log_analytics_signature(workspace_id, shared_key, date, content_length, method, content_type, resource):
    string_to_hash = f"{method}\n{content_length}\n{content_type}\nx-ms-date:{date}\n{resource}"
    decoded_key = base64.b64decode(shared_key)
    encoded_hash = base64.b64encode(
        hmac.new(decoded_key, string_to_hash.encode("utf-8"), digestmod=hashlib.sha256).digest()
    ).decode("utf-8")
    return f"SharedKey {workspace_id}:{encoded_hash}"


def send_log_analytics_data():
    print("\n=== Log Analytics: Injecting Custom Logs ===")
    now = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.%fZ")
    rfc1123 = datetime.datetime.utcnow().strftime("%a, %d %b %Y %H:%M:%S GMT")

    # Fake Heartbeat-like records
    heartbeat_data = []
    for i, vm in enumerate(["vm-web-01", "vm-api-02", "vm-db-03"]):
        heartbeat_data.append({
            "TimeGenerated": now,
            "Computer": vm,
            "OSType": "Windows" if i < 2 else "Linux",
            "Category": "Direct Agent",
            "Version": "10.20.18067",
            "SourceComputerId": f"fake-{vm}-{i:04d}",
            "Environment": "e2e-test"
        })

    # Fake Perf counter records
    perf_data = []
    for vm in ["vm-web-01", "vm-api-02", "vm-db-03"]:
        for counter, obj, val in [
            ("% Processor Time", "Processor", random.uniform(15, 85)),
            ("% Committed Bytes In Use", "Memory", random.uniform(40, 92)),
            ("% Free Space", "LogicalDisk", random.uniform(8, 65)),
            ("Disk Reads/sec", "PhysicalDisk", random.uniform(10, 500)),
            ("Available MBytes", "Memory", random.uniform(512, 8192)),
        ]:
            perf_data.append({
                "TimeGenerated": now,
                "Computer": vm,
                "ObjectName": obj,
                "CounterName": counter,
                "CounterValue": round(val, 2),
                "InstanceName": "_Total",
                "Environment": "e2e-test"
            })

    for log_type, data in [("FakeHeartbeat", heartbeat_data), ("FakePerf", perf_data)]:
        body = json.dumps(data)
        content_length = len(body)
        signature = _build_log_analytics_signature(
            LOG_ANALYTICS_WORKSPACE_ID, LOG_ANALYTICS_SHARED_KEY,
            rfc1123, content_length, "POST", "application/json", "/api/logs"
        )
        req = urllib.request.Request(
            f"https://{LOG_ANALYTICS_WORKSPACE_ID}.ods.opinsights.azure.com/api/logs?api-version=2016-04-01",
            data=body.encode("utf-8"),
            headers={
                "Content-Type": "application/json",
                "Authorization": signature,
                "Log-Type": log_type,
                "x-ms-date": rfc1123,
                "time-generated-field": "TimeGenerated"
            },
            method="POST"
        )
        try:
            resp = urllib.request.urlopen(req)
            print(f"  {log_type}: sent {len(data)} records -> HTTP {resp.status}")
        except urllib.error.HTTPError as e:
            print(f"  {log_type} ERROR: {e.code} - {e.read().decode()}")


# ============================================================================
# 3. Event Hub — Send fake IoT device telemetry
# ============================================================================
def send_event_hub_data():
    print("\n=== Event Hub: Injecting IoT Device Telemetry ===")
    try:
        from azure.eventhub import EventHubProducerClient, EventData

        # Get connection string via Azure CLI
        import subprocess
        result = subprocess.run(
            ["az", "eventhubs", "eventhub", "authorization-rule", "keys", "list",
             "--resource-group", "rg-obsaccel-test",
             "--namespace-name", EVENT_HUB_NAMESPACE,
             "--eventhub-name", EVENT_HUB_NAME,
             "--name", "send-rule",
             "--query", "primaryConnectionString", "-o", "tsv"],
            capture_output=True, text=True
        )

        if result.returncode != 0:
            # Try namespace-level key
            result = subprocess.run(
                ["az", "eventhubs", "namespace", "authorization-rule", "keys", "list",
                 "--resource-group", "rg-obsaccel-test",
                 "--namespace-name", EVENT_HUB_NAMESPACE,
                 "--name", "RootManageSharedAccessKey",
                 "--query", "primaryConnectionString", "-o", "tsv"],
                capture_output=True, text=True
            )

        conn_str = result.stdout.strip()
        if not conn_str:
            print("  WARN: Could not get Event Hub connection string, skipping")
            return

        producer = EventHubProducerClient.from_connection_string(conn_str, eventhub_name=EVENT_HUB_NAME)
        with producer:
            batch = producer.create_batch()
            devices = [
                ("sensor-temp-001", "temperature", 22.5, 35.0, "°C"),
                ("sensor-humidity-002", "humidity", 30.0, 80.0, "%"),
                ("sensor-pressure-003", "pressure", 990.0, 1050.0, "hPa"),
                ("motor-vibration-004", "vibration", 0.1, 5.0, "mm/s"),
                ("valve-flow-005", "flow_rate", 10.0, 100.0, "L/min"),
            ]
            for device_id, metric, low, high, unit in devices:
                for _ in range(5):
                    msg = {
                        "deviceId": device_id,
                        "timestamp": datetime.datetime.utcnow().isoformat() + "Z",
                        "metric": metric,
                        "value": round(random.uniform(low, high), 2),
                        "unit": unit,
                        "location": random.choice(["Plant-A", "Plant-B", "Substation-1"]),
                        "status": random.choice(["normal", "normal", "normal", "warning"]),
                        "environment": "e2e-test"
                    }
                    try:
                        batch.add(EventData(json.dumps(msg)))
                    except ValueError:
                        producer.send_batch(batch)
                        batch = producer.create_batch()
                        batch.add(EventData(json.dumps(msg)))
            producer.send_batch(batch)
            print(f"  Sent {5 * 5} IoT device messages from {len(devices)} devices")

    except ImportError:
        print("  WARN: azure-eventhub not installed, skipping Event Hub injection")
    except Exception as e:
        print(f"  ERROR: {e}")


# ============================================================================
# Main
# ============================================================================
if __name__ == "__main__":
    print("=" * 60)
    print(" Observability Accelerator — Fake Data Injection")
    print(f" Time: {datetime.datetime.utcnow().isoformat()}Z")
    print("=" * 60)

    send_app_insights_telemetry()
    send_log_analytics_data()
    send_event_hub_data()

    print("\n" + "=" * 60)
    print(" Done! Data should appear in Azure Portal within 2-5 minutes.")
    print(" Check:")
    print("   - App Insights > Live Metrics / Transaction search")
    print("   - Log Analytics > Logs > FakeHeartbeat_CL / FakePerf_CL")
    print("   - Event Hub > Overview > Messages chart")
    print("=" * 60)
