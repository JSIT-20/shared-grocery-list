# Shared Grocery List Backend

This repository now contains a Terraform scaffold for an Azure Functions backend and Azure Cosmos DB.

## What is provisioned

- A Linux Consumption Function App using Python
- Four HTTP-triggered functions for grocery list operations
- An Azure Cosmos DB SQL account with free tier enabled
- A SQL database and container with partition key `/item_name`
- Resources are deployed into an existing resource group named `grocery-list`

## Function routes

- `GET /api/items` - list all items
- `POST /api/items` - add an item
- `DELETE /api/items/{item_id}` - delete a specific item
- `DELETE /api/items` - delete all items

## Frontend (GitHub Pages)

A simple static frontend is included in `docs/` and is intended to be served with GitHub Pages.

Features:

- Add items to the grocery list
- Delete one item at a time
- Delete all items with one action
- Mobile-friendly Bootstrap layout

### Configure API URL

The frontend calls the Azure Function App endpoints using a fixed base URL:

- `https://sharedgrocery-fn-vdljxb.azurewebsites.net/api`

For browser access from GitHub Pages, Function App CORS is configured in Terraform using `function_app_cors_allowed_origins`.
The default includes `https://jsit-20.github.io`.

### GitHub Pages deployment

A workflow at `.github/workflows/pages.yml` deploys `docs/` to GitHub Pages on pushes to `main`.

After this workflow is merged, enable GitHub Pages in repository settings using **GitHub Actions** as the source.

## Terraform

Terraform lives in `infra/`.

### Authenticate with a Service Principal

You can authenticate Terraform using an Azure service principal.

Set these environment variables before running Terraform:

```bash
export ARM_SUBSCRIPTION_ID="<subscription-id>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_CLIENT_ID="<app-client-id>"
export ARM_CLIENT_SECRET="<client-secret>"
```

The AzureRM provider reads these values automatically from environment variables.

For CI/CD, store these as GitHub repository secrets.

Required GitHub Actions secrets:

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`

### Remote Terraform State (Azure Storage)

Terraform is configured to use the `azurerm` backend for state.

The workflow passes backend configuration from GitHub Actions secrets during `terraform init`.

Additional required GitHub Actions secrets:

- `TFSTATE_RESOURCE_GROUP_NAME`
- `TFSTATE_STORAGE_ACCOUNT_NAME`
- `TFSTATE_CONTAINER_NAME`
- `TFSTATE_KEY`

The storage account/container must already exist before the workflow runs.

### Service Principal Roles

Minimum role needed to create all resources in this project:

- `Contributor`

Recommended scope for this repo as written:

- Resource-group scope on `grocery-list`, because Terraform uses that existing resource group.

Note: if required Azure resource providers are not already registered in the subscription, provider registration still requires permission at subscription scope.

Typical workflow:

1. `cd infra`
2. `terraform init`
3. `terraform plan`
4. `terraform apply`

Terraform also ZIP-deploys the Python function app from `function_app/`, so the backend code is published during `terraform apply`.

The Function App is configured with the Cosmos SQL connection string from Terraform state, so the Python app can connect without manual secret wiring.
