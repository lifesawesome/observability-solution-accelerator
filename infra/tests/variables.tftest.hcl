# ============================================================================
# Terraform Tests — Variable Validation
# Tests that variable constraints reject invalid inputs
# Run: terraform test
# ============================================================================

variables {
  subscription_id              = "00000000-0000-0000-0000-000000000000"
  customer_name                = "test"
  location                     = "westus2"
  resource_group_name          = "rg-test-obs"
  workspace_sku                = "PerGB2018"
  workspace_retention_days     = 90
  enable_sentinel              = false
  enable_iot_hub               = false
  enable_network_observability = false
  enable_lighthouse            = false
  app_insights_apps            = []
  alert_email_recipients       = []
  tags                         = {}
}

# Valid customer name
run "valid_customer_name" {
  command = plan

  variables {
    customer_name = "marathon-energy"
  }
}

# Invalid customer name with uppercase should fail
run "invalid_customer_name_uppercase" {
  command         = plan
  expect_failures = [var.customer_name]

  variables {
    customer_name = "Marathon"
  }
}

# Invalid customer name with spaces should fail
run "invalid_customer_name_spaces" {
  command         = plan
  expect_failures = [var.customer_name]

  variables {
    customer_name = "marathon energy"
  }
}

# Valid workspace SKU
run "valid_workspace_sku" {
  command = plan

  variables {
    workspace_sku = "CapacityReservation"
  }
}

# Invalid workspace SKU should fail
run "invalid_workspace_sku" {
  command         = plan
  expect_failures = [var.workspace_sku]

  variables {
    workspace_sku = "Free"
  }
}

# Retention too low should fail
run "retention_too_low" {
  command         = plan
  expect_failures = [var.workspace_retention_days]

  variables {
    workspace_retention_days = 7
  }
}

# Retention too high should fail
run "retention_too_high" {
  command         = plan
  expect_failures = [var.workspace_retention_days]

  variables {
    workspace_retention_days = 999
  }
}

# Invalid capacity reservation should fail
run "invalid_capacity_reservation" {
  command         = plan
  expect_failures = [var.capacity_reservation_level]

  variables {
    capacity_reservation_level = 150
  }
}
