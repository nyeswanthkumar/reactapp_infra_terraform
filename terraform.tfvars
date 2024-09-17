# INFO: For all declared variables in variables.tf file has configured with default values, 
# in case to overide default values configure variable name and valued here

resource-group = "react-app-rg"
location       = "westeurope"
vnet-name = "react-app-vnet"
appservice-subnet = "appservice-subnet"
appgw-subnet = "appgwpublic-subnet"
ple-subnet = "ple-subnet"
react-app-endpoint-dns = "reactdataapp"
appgw-backend-pool-healthcheck-probe = "webappsecurehealthcheck"