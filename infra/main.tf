resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
  numeric = true
}

locals {
  name_prefix = lower(replace(var.project_name, "-", ""))

  storage_account_name = substr("${local.name_prefix}${random_string.suffix.result}", 0, 24)
  cosmos_account_name  = substr(lower("${var.project_name}-${random_string.suffix.result}"), 0, 44)
  service_plan_name    = substr(lower("${var.project_name}-plan-${random_string.suffix.result}"), 0, 60)
  function_app_name    = substr(lower("${var.project_name}-fn-${random_string.suffix.result}"), 0, 60)
  database_name        = "grocerydb"
  container_name       = "items"

  common_tags = merge(
    {
      workload = "shared-grocery-list"
    },
    var.tags,
  )
}

data "azurerm_resource_group" "existing" {
  name = "grocery-list"
}

resource "azurerm_storage_account" "functions" {
  name                          = local.storage_account_name
  resource_group_name           = data.azurerm_resource_group.existing.name
  location                      = data.azurerm_resource_group.existing.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  account_kind                  = "StorageV2"
  min_tls_version               = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = local.common_tags
}

resource "azurerm_service_plan" "functions" {
  name                = local.service_plan_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  os_type             = "Linux"
  sku_name            = "Y1"

  tags = local.common_tags
}

resource "azurerm_cosmosdb_account" "this" {
  name                = local.cosmos_account_name
  location            = data.azurerm_resource_group.existing.location
  resource_group_name = data.azurerm_resource_group.existing.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  free_tier_enabled   = true

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = data.azurerm_resource_group.existing.location
    failover_priority = 0
  }

  tags = local.common_tags
}

resource "azurerm_cosmosdb_sql_database" "grocery" {
  name                = local.database_name
  resource_group_name = data.azurerm_resource_group.existing.name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = 400
}

resource "azurerm_cosmosdb_sql_container" "items" {
  name                = local.container_name
  resource_group_name = data.azurerm_resource_group.existing.name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = azurerm_cosmosdb_sql_database.grocery.name
  partition_key_paths = ["/item_name"]
}

resource "azurerm_linux_function_app" "api" {
  name                = local.function_app_name
  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  service_plan_id     = azurerm_service_plan.functions.id

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  functions_extension_version = "~4"
  https_only                  = true

  site_config {
    application_stack {
      python_version = "3.11"
    }

    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    cors {
      allowed_origins = var.function_app_cors_allowed_origins
    }
  }

  app_settings = {
    AzureWebJobsStorage     = azurerm_storage_account.functions.primary_connection_string
    FUNCTIONS_WORKER_RUNTIME = "python"
    COSMOS_CONNECTION_STRING = azurerm_cosmosdb_account.this.primary_sql_connection_string
    COSMOS_DATABASE_NAME     = azurerm_cosmosdb_sql_database.grocery.name
    COSMOS_CONTAINER_NAME    = azurerm_cosmosdb_sql_container.items.name
  }

  tags = local.common_tags
}
