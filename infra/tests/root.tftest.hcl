# ============================================================================
# Terraform Tests — Root Module Validation
# Run: terraform test
# ============================================================================

# Mock the AzureRM provider so tests run without real Azure resources
mock_provider "azurerm" {
  override_data {
    target = module.policy_initiative.data.azurerm_subscription.current
    values = {
      id              = "/subscriptions/00000000-0000-0000-0000-000000000000"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      display_name    = "Test Subscription"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
    }
  }

  override_data {
    target = data.azurerm_resource_group.main
    values = {
      name     = "rg-test-obs"
      location = "westus2"
    }
  }

  override_resource {
    target = module.policy_initiative.azurerm_subscription_policy_assignment.ama_windows
    values = {
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.policy_initiative.azurerm_subscription_policy_assignment.ama_linux
    values = {
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.policy_initiative.azurerm_subscription_policy_assignment.ama_arc_windows
    values = {
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.policy_initiative.azurerm_subscription_policy_assignment.ama_arc_linux
    values = {
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.policy_initiative.azurerm_subscription_policy_assignment.dcr_windows
    values = {
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }

  override_resource {
    target = module.policy_initiative.azurerm_subscription_policy_assignment.dcr_linux
    values = {
      subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

# Validate that the root module initializes and plans without errors
# using the example tfvars

variables {
  subscription_id              = "00000000-0000-0000-0000-000000000000"
  customer_name                = "test"
  location                     = "westus2"
  resource_group_name          = "rg-test-obs"
  workspace_sku                = "PerGB2018"
  workspace_retention_days     = 90
  enable_sentinel              = true
  enable_iot_hub               = false
  enable_network_observability = false
  enable_lighthouse            = false
  app_insights_apps            = ["webapp"]
  alert_email_recipients       = ["test@example.com"]
  tags = {
    environment = "test"
  }
}

# Validate naming conventions
run "naming_conventions" {
  command = plan

  assert {
    condition     = can(regex("^la-test-obs$", module.log_analytics.workspace_name))
    error_message = "Workspace name should follow 'la-{customer}-obs' pattern"
  }
}

# Validate feature flag: Sentinel enabled
run "sentinel_enabled" {
  command = plan

  variables {
    enable_sentinel = true
  }

  assert {
    condition     = length(module.sentinel) == 1
    error_message = "Sentinel module should be deployed when enable_sentinel=true"
  }
}

# Validate feature flag: Sentinel disabled
run "sentinel_disabled" {
  command = plan

  variables {
    enable_sentinel = false
  }

  assert {
    condition     = length(module.sentinel) == 0
    error_message = "Sentinel module should not be deployed when enable_sentinel=false"
  }
}

# Validate feature flag: IoT Hub disabled by default
run "iot_hub_disabled_by_default" {
  command = plan

  assert {
    condition     = length(module.iot_hub) == 0
    error_message = "IoT Hub should not be deployed by default"
  }
}

# Validate Application Insights creates one per app
run "app_insights_per_app" {
  command = plan

  variables {
    app_insights_apps = ["webapp", "api"]
  }

  assert {
    condition     = length(module.app_insights) == 2
    error_message = "Should create one App Insights per app in the list"
  }
}
