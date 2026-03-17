# ============================================================================
# IoT Hub Module
# Deploys Azure IoT Hub for OT/IoT device telemetry ingestion
# with message routing to Event Hubs for downstream analytics
# ============================================================================

resource "azurerm_iothub" "this" {
  name                = var.iot_hub_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags

  sku {
    name     = var.sku
    capacity = var.capacity
  }

  # Retain messages for 7 days (max) for replay scenarios
  event_hub_retention_in_days = 7
  event_hub_partition_count   = var.partition_count
}

# ============================================================================
# Event Hub Namespace for IoT telemetry routing
# (Fabric and ADX consume from here)
# ============================================================================
resource "azurerm_eventhub_namespace" "iot_telemetry" {
  name                = "evhns-${var.iot_hub_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  capacity            = 1
  tags                = var.tags
}

resource "azurerm_eventhub" "device_telemetry" {
  name              = "device-telemetry"
  namespace_id      = azurerm_eventhub_namespace.iot_telemetry.id
  partition_count   = var.partition_count
  message_retention = 7
}

resource "azurerm_eventhub_authorization_rule" "iot_send" {
  name         = "iot-hub-send"
  eventhub_name = azurerm_eventhub.device_telemetry.name
  namespace_name = azurerm_eventhub_namespace.iot_telemetry.name
  resource_group_name = var.resource_group_name
  send   = true
  listen = false
  manage = false
}

resource "azurerm_eventhub_authorization_rule" "fabric_listen" {
  name         = "fabric-listen"
  eventhub_name = azurerm_eventhub.device_telemetry.name
  namespace_name = azurerm_eventhub_namespace.iot_telemetry.name
  resource_group_name = var.resource_group_name
  send   = false
  listen = true
  manage = false
}

# ============================================================================
# IoT Hub Route - Send device telemetry to Event Hub
# ============================================================================
resource "azurerm_iothub_route" "telemetry_to_eventhub" {
  name                = "telemetry-to-eventhub"
  resource_group_name = var.resource_group_name
  iothub_name         = azurerm_iothub.this.name
  source              = "DeviceMessages"
  condition           = "true"
  endpoint_names      = [azurerm_iothub_endpoint_eventhub.telemetry.name]
  enabled             = true
}

resource "azurerm_iothub_endpoint_eventhub" "telemetry" {
  resource_group_name = var.resource_group_name
  iothub_id           = azurerm_iothub.this.id
  name                = "eventhub-telemetry"
  connection_string   = azurerm_eventhub_authorization_rule.iot_send.primary_connection_string
}
