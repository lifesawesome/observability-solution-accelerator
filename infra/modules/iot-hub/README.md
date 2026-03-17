# IoT Hub Module

Deploys Azure IoT Hub with Event Hub routing for OT/IoT telemetry.

## What It Deploys
- Azure IoT Hub (device management + telemetry ingestion)
- Event Hub Namespace + Hub for downstream analytics
- Message route: IoT Hub → Event Hub (all device messages)
- Separate auth rules: IoT Hub (send), Fabric/ADX (listen)

## Data Flow

```
OT Devices → IoT Edge → IoT Hub → Event Hub → Fabric KQL DB / Lakehouse
                                             → ADX (alternative)
```

## Usage

```hcl
module "iot_hub" {
  source = "./modules/iot-hub"

  resource_group_name = "rg-customer-obs"
  location            = "eastus2"
  iot_hub_name        = "iot-marathon-obs"
  sku                 = "S1"
  capacity            = 1
}
```
