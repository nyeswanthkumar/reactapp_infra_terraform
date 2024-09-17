# React Data App variables declartion and default values configured here
# In case to overide default varible values, configure it in terraform.tfvars file

variable "resource-group" {
  type        = string
  description = "azure resource group name"
}

variable "location" {
  type        = string
  description = "azure resources location"
}

variable "vnet-name" {
  type        = string
  description = "virtual network name (vnet)"
}

variable "vnet-address" {
  type        = list(string)
  description = "vnet address in CIDR format"
  default = ["10.0.0.0/16"]
}

variable "appservice-subnet" {
  type        = string
  description = "appservice subnet name"
}

variable "appgw-subnet" {
  type        = string
  description = "application gateway subnet name"
}

variable "ple-subnet" {
  type        = string
  description = "ple subnet name"
}

variable "appgw-subnet-address" {
  type        = list(string)
  description = "application gateway subnet address in CIDR format"
  default = ["10.0.1.0/27"]
}

variable "appservice-subnet-address" {
  type        = list(string)
  description = "appservice subnet address in CIDR format"
  default = ["10.0.2.0/27"]
}

variable "ple-subnet-address" {
   type        = list(string)
  description = "ple subnet address in CIDR format"
  default = ["10.0.3.0/27"]
}

variable "appgw-subnet-nsg-name" {
  type        = string
  description = "application gateway subnet nsg name"
  default = "appgw-subnet-nsg"
}

variable "appservice-subnet-nsg-name" {
  type        = string
  description = "webapp service subnet nsg name"
  default = "appservice-subnet-nsg"
}

variable "ple-subnet-nsg-name" {
  type        = string
  description = "ple subnet nsg name"
  default = "ple-subnet-nsg"
}


variable "react-acr-name" {
  type        = string
  description = "azure container registry name"
  default = "reactacr01"
}

variable "react-acr-sku" {
  type        = string
  description = "azure container registry sku"
  default = "Basic"
}


variable "react-app-appservice-plan-name" {
  type        = string
  description = "webapp service plan name"
  default = "react-app-service-plan-01"
}

variable "react-app-appservice-plan-sku" {
  type        = string
  description = "webapp service plan sku minimum S1"
  default = "S1"
}

variable "react-app-appservice-plan-os" {
  type        = string
  description = "webapp service plan os type"
  default = "Linux"
}

variable "react-webapp-service-name" {
  type        = string
  description = "azure webapp service name"
  default = "react-webapp-service-container"
}

variable "react-webapp-docker-image-default" {
  type        = string
  description = "default docker image name from mcr registry "
  default = "appsvc/staticsite:latest"
}

variable "react-webapp-service-container-ple-name" {
  type        = string
  description = "webapp serice private endpoint name"
  default = "react-webapp-service-container-ple"
}

variable "react-app-service-plan-autoscale-name" {
  type        = string
  description = "appservice plan autoscaling profile name"
  default = "react-app-service-plan-autoscale-01"
}

variable "autoscaling-notification-emails" {
  type        = list(string)
  description = "autoscaling setting notification emails addresses"
  default =  ["yeswanthk68@gmail.com"]
}

variable "react-data-app-public-ip-name" {
  type        = string
  description = "react data app public ip name"
  default = "react-data-app-public-ip"
}

variable "react-app-appgw-name" {
  type        = string
  description = "react data application gateway name"
  default = "react-app-appgw"
}

variable "react-app-appgw-sku" {
  type        = string
  description = "react data application gateway sku with Web Application Firewal for Layer7 protection"
  default = "Standard_v2"
}

variable "react-app-appgw-min-capacity" {
  type        = number
  description = "react data application gateway min instance count"
  default = 1
}

variable "react-app-appgw-max-capacity" {
  type        = number
  description = "react data application gateway max instance count, value should be greater than 1, eg: 2"
  default = 2
}

variable "react-app-appgw-unsecure-port" {
  type        = number
  description = "application gateway unsecure port number for listener configurations"
  default = 80
}

variable "react-app-appgw-secure-port" {
  type        = number
  description = "application gateway secure port number for listener configurations"
  default = 443
}

variable "react-app-loganalytics-Workspace-name" {
  type        = string
  description = "log analytics workspace name"
  default = "react-app-loganalytics-Workspace"
}

variable "react-app-loganalytics-Workspace-sku" {
  type        = string
  description = "log analytics workspace sku"
  default = "PerGB2018"
}

variable "react-app-loganalytics-Workspace-retention-days" {
  type        = number
  description = "log analytics workspace data retention days"
  default = 30
}

variable "react-app-mssql-mi-name" {
  type        = string
  description = "user managed identity for mssql server"
  default = "react-app-mssql-mi"
}

variable "react-app-kv-mssql-name" {
  type        = string
  description = "keyvault name for mssql server"
  default = "react-app-kv-mssql"
}

variable "react-app-kv-sku" {
  type        = string
  description = "keyvault name for mssql server sku"
  default = "standard"
}
variable "react-app-kv-sqlkey-01-name" {
  type        = string
  description = "mssql keyvault encryption key name"
  default = "react-app-kv-sqlkey-01"
}

variable "react-app-keyvault-ple-name" {
  type        = string
  description = "mssql keyvault ple name"
  default = "react-app-keyvault-ple"
}

variable "react-app-mssql-server-name" {
  type        = string
  description = "mssql server name"
  default = "react-app-mssql-server"
}


variable "react-app-database-name" {
  type        = string
  description = "mssql database name"
  default = "react-app-database"
}

variable "react-app-database-sku" {
  type        = string
  description = "mssql database sku"
  default = "S0"
}

variable "react-app-database-maxsize" {
  type        = number
  description = "mssql database capacity in GBs"
  default = 10
}

variable "react-app-mssql-ple-name" {
  type        = string
  description = "mssql server private endpoint name"
  default = "react-app-mssql-ple"
}

variable "react-app-endpoint-dns" {
  type        = string
  description = "react data application public ip dns name"
  default = "reactdataapp"
}

variable "appgw-backend-pool-healthcheck-probe" {
  type        = string
  description = "resources location name"
  default = "webappsecurehealthcheck"
}

variable "docker-registry-url-default" {
  type        = string
  description = "docker registry url default is mcr"
  default = "https://mcr.microsoft.com"
}

# reactapp_infra_prerequiste applicaiton configurations
variable "react-app-config-kv-name" {
  type        = string
  description = "azure keyvault to read secrets configurations"
  default = "react-app-config-kv"
}

variable "react-app-config-rg-name" {
  type        = string
  description = "resources location name"
  default = "react-app-config-rg"
}

variable "react-app-config-storage-name" {
  type        = string
  description = "resources location name"
  default = "statefilereactapp"
}
