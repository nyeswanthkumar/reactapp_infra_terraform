terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.0.1"
    }
  }
}

provider "azurerm" {
  tenant_id       = "azure tenant id"
  subscription_id = "azure subscription id"
  client_id       = "azure AD app registration client id"
  client_secret   = ""
  features {

  }
}

# Maintain Terraform statefile in Storage Account instead of local systems
terraform {
  backend "azurerm" {
    resource_group_name  = "react-app-config-rg"
    storage_account_name = "statefilereactapp"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
    access_key           = ""
  }
}


# Declare local variables
locals {
  tags = {
    ProjectName = "react-data-app"
    Environment = "Development"
    Owner = "Dev Team"
  }
  
  backend_address_pool_name      = "react-webapp-backend-pool"
  frontend_port_name             = "appgw-public-frontend-port"
  frontend_ip_configuration_name = "appgw-frontend-ip-configuration"
  http_setting_name              = "backend-webapp-http-settings"
  listener_name                  = "appgw-frontend-public-listener"
  request_routing_rule_name      = "appgw-routing-rule-react-app"
  gateway_ip_configuration_name = "gateway_ip_configuration"
}

# Configuration of AzureRM provider
data "azurerm_client_config" "current_rm_config" {}

# Read Secrets from Azure keyvault config resource
data "azurerm_key_vault" "react-app-config-kv" {
  name                = var.react-app-config-kv-name
  resource_group_name = var.react-app-config-rg-name
}

data "azurerm_key_vault_secrets" "react-app-secrets-names" {
  key_vault_id = data.azurerm_key_vault.react-app-config-kv.id
}

data "azurerm_key_vault_secret" "read_secret_value" {
  for_each     = toset(data.azurerm_key_vault_secrets.react-app-secrets-names.names)
  name         = each.key
  key_vault_id = data.azurerm_key_vault.react-app-config-kv.id
}

# Ouput secrets from keyvault config
output "sqlserver_username" {
  value = data.azurerm_key_vault_secret.read_secret_value["react-app-mssql-server-username"].value
  sensitive = true
}

output "sqlserver_password" {
  value = data.azurerm_key_vault_secret.read_secret_value["react-app-mssql-server-password"].value
  sensitive = true
}

# Azure Resouce Group Creation
resource "azurerm_resource_group" "react_app_rg" {
  name     = var.resource-group
  location = var.location
  tags = local.tags
}

# Netework Infrastrcuture started

#VNet and Virtual Network creation
resource "azurerm_virtual_network" "react-app-vnet-dev" {
  name                = var.vnet-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  address_space       = var.vnet-address
  tags = local.tags
}

resource "azurerm_subnet" "appgw-subnet" {
  name                 = var.appgw-subnet
  resource_group_name  = azurerm_resource_group.react_app_rg.name
  virtual_network_name = azurerm_virtual_network.react-app-vnet-dev.name
  address_prefixes     = var.appgw-subnet-address
}

resource "azurerm_subnet" "appservice-subnet" {
  name                 = var.appservice-subnet
  resource_group_name  = azurerm_resource_group.react_app_rg.name
  virtual_network_name = azurerm_virtual_network.react-app-vnet-dev.name
  address_prefixes     = var.appservice-subnet-address
  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [ 
        "Microsoft.Network/virtualNetworks/subnets/action"
       ]
    }
  }
}

resource "azurerm_subnet" "ple-subnet" {
  name                 = var.ple-subnet
  resource_group_name  = azurerm_resource_group.react_app_rg.name
  virtual_network_name = azurerm_virtual_network.react-app-vnet-dev.name
  address_prefixes     = var.ple-subnet-address
}

# Network Security Group creation for subnets

resource "azurerm_network_security_group" "appgw-subnet-nsg" {
  name                = var.appgw-subnet-nsg-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

resource "azurerm_network_security_group" "appservice-subnet-nsg" {
  name                = var.appservice-subnet-nsg-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

resource "azurerm_network_security_group" "ple-subnet-nsg" {
  name                = var.ple-subnet-nsg-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

# Vnet Subnets and Network Security Group assoication

resource "azurerm_subnet_network_security_group_association" "appgw-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.appgw-subnet.id
  network_security_group_id = azurerm_network_security_group.appgw-subnet-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "appservice-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.appservice-subnet.id
  network_security_group_id = azurerm_network_security_group.appservice-subnet-nsg.id
}

resource "azurerm_subnet_network_security_group_association" "ple-subnet-nsg-association" {
  subnet_id                 = azurerm_subnet.ple-subnet.id
  network_security_group_id = azurerm_network_security_group.ple-subnet-nsg.id
}

# Creating Private DNS Zones for websites, vault, and sqlserver and associate with Vnet
resource "azurerm_private_dns_zone" "dnsprivatezone-webapp" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnetdnszonelink-webapp" {
  name = "vnetdnszonelink-webapp"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsprivatezone-webapp.name
  virtual_network_id = azurerm_virtual_network.react-app-vnet-dev.id
}

resource "azurerm_private_dns_zone" "dnsprivatezone-vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnetdnszonelink-vault" {
  name = "vnetdnszonelink-vault"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsprivatezone-vault.name
  virtual_network_id = azurerm_virtual_network.react-app-vnet-dev.id
}

resource "azurerm_private_dns_zone" "dnsprivatezone-sqldb" {
  name                = "privatelink.database.windows.net"
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnetdnszonelink-sqldb" {
  name = "vnetdnszonelink-sqldb"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dnsprivatezone-sqldb.name
  virtual_network_id = azurerm_virtual_network.react-app-vnet-dev.id
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "react-app-loganalytics-Workspace" {
  name                = var.react-app-loganalytics-Workspace-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  sku                 = var.react-app-loganalytics-Workspace-sku
  retention_in_days   = var.react-app-loganalytics-Workspace-retention-days
}

# Configure Inbound and Outbound rules on all Nerwork security groups
resource "azurerm_network_security_rule" "inbound_rule_agw_intrasubnet-traffice" {
  name                        = "inbound_rule_agw_intrasubnet-traffice"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.1.0/27"
  destination_address_prefix  = "10.0.1.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "inbound_azurelb-appgwpublic" {
  name                        = "inbound_azurelb-appgwpublic"
  priority                    = 410
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "10.0.1.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}


resource "azurerm_network_security_rule" "inbound_healthProbeV2-from-gatewaymanager" {
  name                        = "inbound_healthProbeV2-from-gatewaymanager"
  priority                    = 420
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "inboud-rule-internet-traffic-secure" {
  name                        = "inboud-rule-internet-traffic-secure"
  priority                    = 430
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "10.0.1.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "inboud-rule-internet-traffic-unsecure" {
  name                        = "inboud-rule-internet-traffic-unsecure"
  priority                    = 431
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "10.0.1.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound_rule_agw_intrasubnet-traffice" {
  name                        = "outbound_rule_agw_intrasubnet-traffice"
  priority                    = 400
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.1.0/27"
  destination_address_prefix  = "10.0.1.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound-appgw-azurecloud-secure" {
  name                        = "outbound-appgw-azurecloud-secure"
  priority                    = 410
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.1.0/27"
  destination_address_prefix  = "AzureCloud"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound-appgw-azurecloud" {
  name                        = "outbound-appgw-azurecloud_secure"
  priority                    = 420
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "10.0.1.0/27"
  destination_address_prefix  = "AzureCloud"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appgw-subnet-nsg.name
}

resource "azurerm_network_security_rule" "inbound_rule_agw_to_ple_secure" {
  name                        = "inbound_rule_agw_to_ple_secure"
  priority                    = 400
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.1.0/27"
  destination_address_prefix  = "10.0.3.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.ple-subnet-nsg.name
}

resource "azurerm_network_security_rule" "inbound_rule_agw_to_ple_unsecure" {
  name                        = "inbound_rule_agw_to_ple_unsecure"
  priority                    = 410
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "10.0.1.0/27"
  destination_address_prefix  = "10.0.3.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.ple-subnet-nsg.name
}

resource "azurerm_network_security_rule" "inbound_rule_appservice_to_ple" {
  name                        = "inbound_rule_appservice_to_ple"
  priority                    = 420
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.2.0/27"
  destination_address_prefix  = "10.0.3.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.ple-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound_rule_appservice_intrasubnet-traffice" {
  name                        = "outbound_rule_appservice_intrasubnet-traffice"
  priority                    = 400
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "10.0.2.0/27"
  destination_address_prefix  = "10.0.2.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appservice-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound_rule_appservice_to_ple" {
  name                        = "outbound_rule_appservice_to_ple"
  priority                    = 410
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1-59999"
  source_address_prefix       = "10.0.2.0/27"
  destination_address_prefix  = "10.0.3.0/27"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appservice-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound_rule_appservice_to_azurecloud" {
  name                        = "outbound_rule_appservice_to_azurecloud"
  priority                    = 420
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.2.0/27"
  destination_address_prefix  = "AzureCloud"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appservice-subnet-nsg.name
}

resource "azurerm_network_security_rule" "outbound_rule_appservice_to_Internet" {
  name                        = "outbound_rule_appservice_to_Internet"
  priority                    = 430
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.2.0/27"
  destination_address_prefix  = "Internet"
  resource_group_name = azurerm_resource_group.react_app_rg.name
  network_security_group_name = azurerm_network_security_group.appservice-subnet-nsg.name
}

# Netswork Infrastrcuture ended

# Create Azure Container Registry to store webapp docker images
resource "azurerm_container_registry" "react-acr-01" {
  name                = var.react-acr-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  sku                 = var.react-acr-sku
  admin_enabled       = true
  tags = local.tags
}

# Linux App Service plan for WebApp container service, minimum sku S1 is required for Autoscaling feature
# Auto scalling resource declread at last
resource "azurerm_service_plan" "react-app-service-plan-01" {
  name                = var.react-app-appservice-plan-name
  resource_group_name = azurerm_resource_group.react_app_rg.name
  location            = azurerm_resource_group.react_app_rg.location
  os_type             = var.react-app-appservice-plan-os
  sku_name            = var.react-app-appservice-plan-sku
}

# Create Azure WebApp container service app with Basic B1 plan and with Ngnix docker image.
# From application deploy pipeline we will push accutual Webapp image from Azure Container Registry 
# Using this webapp SystemIdentity, we will access MSSql database, for this we have to create a External user account in Database and set read, write acccess.
resource "azurerm_linux_web_app" "react-webapp-service-container" {
  name                = var.react-webapp-service-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  service_plan_id     = azurerm_service_plan.react-app-service-plan-01.id
  public_network_access_enabled = false
  client_affinity_enabled = true
  https_only = true
  depends_on = [ 
    azurerm_container_registry.react-acr-01
   ]

  app_settings = {
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  site_config {
    always_on = true
    application_stack {
      docker_image_name   = var.react-webapp-docker-image-default
      docker_registry_url = var.docker-registry-url-default
      docker_registry_username = azurerm_container_registry.react-acr-01.admin_username
      docker_registry_password = azurerm_container_registry.react-acr-01.admin_password
    }
  }

  identity {
    type         = "SystemAssigned"
  }
}

# Azure WebApp Vnet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "appservicevnetintegration" {
  app_service_id  = azurerm_linux_web_app.react-webapp-service-container.id
  subnet_id       = azurerm_subnet.appservice-subnet.id
  depends_on = [ 
    azurerm_linux_web_app.react-webapp-service-container 
  ]
}

# Azure WebApp Private Link Enpoint connection
resource "azurerm_private_endpoint" "react-webapp-service-container-ple" {
  name                = var.react-webapp-service-container-ple-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  subnet_id           = azurerm_subnet.ple-subnet.id
  depends_on = [ 
    azurerm_linux_web_app.react-webapp-service-container
  ]

  private_dns_zone_group {
    name = "privatednszonegroup-webapp"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.dnsprivatezone-webapp.id
      ]
  }

  private_service_connection {
    name = "appservicepleconnection"
    private_connection_resource_id = azurerm_linux_web_app.react-webapp-service-container.id
    subresource_names = ["sites"]
    is_manual_connection = false
  }
}

# App service plan Auto scalling rules default, weekdays, weekends
resource "azurerm_monitor_autoscale_setting" "react-app-service-plan-autoscale-01" {
  name                = var.react-app-service-plan-autoscale-name
  resource_group_name = azurerm_resource_group.react_app_rg.name
  location            = azurerm_resource_group.react_app_rg.location
  target_resource_id  = azurerm_service_plan.react-app-service-plan-01.id
  depends_on = [ 
    azurerm_service_plan.react-app-service-plan-01
  ]

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.react-app-service-plan-01.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "Microsoft.Web/serverFarms"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.react-app-service-plan-01.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 50
        metric_namespace   = "Microsoft.Web/serverFarms"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
  }

  profile {
    name = "weekdays-profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 4
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.react-app-service-plan-01.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "Microsoft.Web/serverFarms"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.react-app-service-plan-01.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 50
        metric_namespace   = "Microsoft.Web/serverFarms"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    recurrence {
        timezone = "Central European Standard Time"
        days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        hours    = [0]
        minutes  = [0]

      }
  }

  profile {
    name = "weekends-profile"

    capacity {
      default = 1
      minimum = 1
      maximum = 2
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.react-app-service-plan-01.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "Microsoft.Web/serverFarms"
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.react-app-service-plan-01.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 50
        metric_namespace   = "Microsoft.Web/serverFarms"
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }
    recurrence {
        timezone = "Central European Standard Time"
        days     = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        hours    = [0]
        minutes  = [0]

      }
  }

  notification {
    email {
      custom_emails        = var.autoscaling-notification-emails
    }
  }
}

# Public Ip Address with DNS to access react webapp services
resource "azurerm_public_ip" "appgw-public-frontend-ip" {
  name                = var.react-data-app-public-ip-name
  resource_group_name = azurerm_resource_group.react_app_rg.name
  location            = azurerm_resource_group.react_app_rg.location
  allocation_method   = "Static"
  domain_name_label   = var.react-app-endpoint-dns
}

# Azure Application Gateway
resource "azurerm_application_gateway" "react-app-appgw" {
  name                = var.react-app-appgw-name
  resource_group_name = azurerm_resource_group.react_app_rg.name
  location            = azurerm_resource_group.react_app_rg.location
  depends_on = [ 
    azurerm_private_endpoint.react-webapp-service-container-ple,
    azurerm_network_security_rule.inbound_healthProbeV2-from-gatewaymanager,
    azurerm_linux_web_app.react-webapp-service-container
    ]

  sku {
    name     = var.react-app-appgw-sku
    tier     = var.react-app-appgw-sku
  }

  autoscale_configuration {
    min_capacity = var.react-app-appgw-min-capacity
    max_capacity = var.react-app-appgw-max-capacity
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = azurerm_subnet.appgw-subnet.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = var.react-app-appgw-unsecure-port
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.appgw-public-frontend-ip.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
    fqdns = [ 
      azurerm_linux_web_app.react-webapp-service-container.default_hostname 
      ]
  }

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = var.react-app-appgw-secure-port
    protocol              = "Https"
    request_timeout       = 90
    pick_host_name_from_backend_address = true
    probe_name = var.appgw-backend-pool-healthcheck-probe
  }

  probe {
    name = var.appgw-backend-pool-healthcheck-probe
    pick_host_name_from_backend_http_settings = true
    interval = 60
    path = "/"
    port = var.react-app-appgw-secure-port
    protocol = "Https"
    timeout = 60
    unhealthy_threshold = 5
    match {
      #body = <> we can validate with response body as well
      status_code = [ #Success health check https status codes
        "200"
        ]
    }
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = local.request_routing_rule_name
    priority                   = 10
    rule_type                  = "Basic"
    http_listener_name         = local.listener_name
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.http_setting_name
  }
}

# WebApp service diagnostics setting and send information to log analytics workspace
data "azurerm_monitor_diagnostic_categories" "react-webapp-service" {
  resource_id = azurerm_linux_web_app.react-webapp-service-container.id
}

resource "azurerm_monitor_diagnostic_setting" "react-webapp-service-diagnostic-settings" {
  name                       = "react-webapp-service-diagnostic-setting"
  target_resource_id         = azurerm_linux_web_app.react-webapp-service-container.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.react-app-loganalytics-Workspace.id

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.react-webapp-service.metrics
    content {
      category = metric.value
      enabled  = true
    }
  }

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.react-webapp-service.log_category_types
    content {
      category = enabled_log.value
    }
  }
}

# Application Gateway diagnostics setting and send information to log analytics workspace
data "azurerm_monitor_diagnostic_categories" "react-aapgw-service" {
  resource_id = azurerm_application_gateway.react-app-appgw.id
}

resource "azurerm_monitor_diagnostic_setting" "react-aapgw-service-diagnostic-settings" {
name                       = "react-aapgw-service-diagnostic-settings"
  target_resource_id         = azurerm_application_gateway.react-app-appgw.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.react-app-loganalytics-Workspace.id

  dynamic "metric" {
    for_each = data.azurerm_monitor_diagnostic_categories.react-aapgw-service.metrics
    content {
      category = metric.value
      enabled  = true
    }
  }

  dynamic "enabled_log" {
    for_each = data.azurerm_monitor_diagnostic_categories.react-aapgw-service.log_category_types
    content {
      category = enabled_log.value
    }
  }
}


# User Manager Identity for MSSQL server
resource "azurerm_user_assigned_identity" "react-app-mssql-mi" {
  name                = var.react-app-mssql-mi-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
}

#Azure keyvault resouce to store MSSQL server encryption key
resource "azurerm_key_vault" "react-app-kv-mssql" {
  name                        = var.react-app-kv-mssql-name
  location                    = azurerm_resource_group.react_app_rg.location
  resource_group_name         = azurerm_resource_group.react_app_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current_rm_config.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  sku_name = var.react-app-kv-sku
  public_network_access_enabled = true
  depends_on = [ 
    azurerm_user_assigned_identity.react-app-mssql-mi 
    ]

  access_policy {
    tenant_id = data.azurerm_client_config.current_rm_config.tenant_id
    object_id = data.azurerm_client_config.current_rm_config.object_id

    key_permissions = ["Get", "List", "Create", "Delete", "Update", "Recover", "Purge", "GetRotationPolicy"]
  }

  access_policy {
    tenant_id = azurerm_user_assigned_identity.react-app-mssql-mi.tenant_id
    object_id = azurerm_user_assigned_identity.react-app-mssql-mi.principal_id

    key_permissions = ["Get", "WrapKey", "UnwrapKey", "List"]
  }
}

# Azure Keyvault Private Link Enpoint connection
resource "azurerm_private_endpoint" "react-app-keyvault-ple" {
  name                = var.react-app-keyvault-ple-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  subnet_id           = azurerm_subnet.ple-subnet.id
  depends_on = [ 
    azurerm_key_vault.react-app-kv-mssql
  ]

  private_dns_zone_group {
    name = "privatednszonegroup-vault"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.dnsprivatezone-vault.id
      ]
  }

  private_service_connection {
    name = "keyvaultpleconnection"
    private_connection_resource_id = azurerm_key_vault.react-app-kv-mssql.id
    subresource_names = ["vault"]
    is_manual_connection = false
  }
}

# Azure keyvault key generation for encryption and decryption, used by MSSQL server

resource "azurerm_key_vault_key" "react-app-kv-sqlkey" {
  name         = var.react-app-kv-sqlkey-01-name
  key_vault_id = azurerm_key_vault.react-app-kv-mssql.id
  key_type     = "RSA"
  key_size     = 2048
  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey"
    ]

  depends_on = [ azurerm_private_endpoint.react-app-keyvault-ple ]
}

# Azure SQL Server Creation
resource "azurerm_mssql_server" "react-app-mssql-server" {
  name                         = var.react-app-mssql-server-name
  resource_group_name          = azurerm_resource_group.react_app_rg.name
  location                     = azurerm_resource_group.react_app_rg.location
  version                      = "12.0"
  administrator_login          = data.azurerm_key_vault_secret.read_secret_value["react-app-mssql-server-username"].value
  administrator_login_password = data.azurerm_key_vault_secret.read_secret_value["react-app-mssql-server-password"].value
  minimum_tls_version          = "1.2"
  public_network_access_enabled = false
  depends_on = [ 
    azurerm_key_vault.react-app-kv-mssql,
    azurerm_key_vault_key.react-app-kv-sqlkey,
    azurerm_user_assigned_identity.react-app-mssql-mi  
   ]

  azuread_administrator {
    login_username = azurerm_user_assigned_identity.react-app-mssql-mi.name
    object_id      = azurerm_user_assigned_identity.react-app-mssql-mi.principal_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.react-app-mssql-mi.id
      ]
  }

  primary_user_assigned_identity_id            = azurerm_user_assigned_identity.react-app-mssql-mi.id
  transparent_data_encryption_key_vault_key_id = azurerm_key_vault_key.react-app-kv-sqlkey.id
}

# MSSQL Database creation
resource "azurerm_mssql_database" "react-app-database" {
  name           = var.react-app-database-name
  server_id      = azurerm_mssql_server.react-app-mssql-server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = var.react-app-database-maxsize
  sku_name       = var.react-app-database-sku
  zone_redundant = false
  enclave_type   = "VBS"
  depends_on = [ 
    azurerm_mssql_server.react-app-mssql-server 
    ]

  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

# Azure MSSQL Server Private Link Enpoint connection
resource "azurerm_private_endpoint" "react-app-mssql-ple" {
  name                = var.react-app-mssql-ple-name
  location            = azurerm_resource_group.react_app_rg.location
  resource_group_name = azurerm_resource_group.react_app_rg.name
  subnet_id           = azurerm_subnet.ple-subnet.id
  depends_on = [ 
    azurerm_mssql_server.react-app-mssql-server
  ]

  private_dns_zone_group {
    name = "privatednszonegroup-sqldb"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsprivatezone-sqldb.id]
  }

  private_service_connection {
    name = "mssqlpleconnection"
    private_connection_resource_id = azurerm_mssql_server.react-app-mssql-server.id
    subresource_names = ["sqlserver"]
    is_manual_connection = false
  }
}