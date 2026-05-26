output "resource_group_name" {
  value = data.azurerm_resource_group.existing.name
}

output "function_app_name" {
  value = azurerm_linux_function_app.api.name
}

output "function_app_default_hostname" {
  value = azurerm_linux_function_app.api.default_hostname
}

output "cosmos_account_name" {
  value = azurerm_cosmosdb_account.this.name
}

output "cosmos_database_name" {
  value = azurerm_cosmosdb_sql_database.grocery.name
}

output "cosmos_container_name" {
  value = azurerm_cosmosdb_sql_container.items.name
}
