resource_groups = {
  rg1 = {
    name     = "test_rg"
    location = "North Europe"
  }
}



vnets = {
  vnet1 = {
    vnet_name     = "sahilavnet-uat"
    location      = "North Europe"
    rg_name       = "sahil-uat-rg1"
    address_space = ["10.0.0.0/23"]
    subnets = {
      subnet1 = { subnet_name = "sahilasubnet", subnet_address_prefixes = ["10.0.0.0/24"] }
      subnet2 = { subnet_name = "secondsubnet",  subnet_address_prefixes = ["10.0.1.0/25"] }
      subnetab = { subnet_name = "AzureBastionSubnet", subnet_address_prefixes = ["10.0.1.128/26"] }
      subnet3 = { subnet_name = "thirdsubnet",  subnet_address_prefixes = ["10.0.1.192/27"] }
    }
  }
}



nsg = {
  web_nsg = {
    nsg_name = "sahilansg-uat"
    location = "North Europe"
    rg_name  = "sahil-uat-rg1"
    security_rules = {
      allow_http = {
        security_rule_name         = "allow-http"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
      }
    }
  }
  empty_rule_nsg = {
    nsg_name = "secondnsg-uat"
    location = "North Europe"
    rg_name  = "sahil-uat-rg1"
  }
}

nics = {
  nic1 = {
    nic_name    = "sahilanic-uat"
    rg_name     = "sahil-uat-rg1"
    location    = "North Europe"
    vnet_name   = "sahilavnet-uat"
    subnet_name = "sahilasubnet"
    ip_configurations = {
      ipconfig1 = {
        ip_config_name        = "sahila-internal-uat"
        private_ip_allocation = "Dynamic"
        public_ip_name        = null
      }
    }
  }
  nic2 = {
    nic_name    = "secondnic-uat"
    rg_name     = "sahil-uat-rg1"
    location    = "North Europe"
    vnet_name   = "sahilavnet-uat"
    subnet_name = "secondsubnet"
    ip_configurations = {
      ipconfig2 = {
        ip_config_name        = "second-internal-uat"
        private_ip_allocation = "Dynamic"
        primary               = true
      }
      ipconfig3 = {
        ip_config_name        = "third-internal-uat"
        private_ip_allocation = "Static"
        private_ip_address    = "10.0.1.75"
        public_ip_name        = null
      }
    }
  }
}

pips = {
  bastionpip = { pip_name = "bastionpip-uat", location = "North Europe", rg_name = "sahil-uat-rg1" }
  loadbalancer = { pip_name = "loadbalancerpip-uat", location = "North Europe", rg_name = "sahil-uat-rg1" }
}

bastion = {
  bastion1 = {
    bastion_name = "sahilabastion-uat"
    location     = "North Europe"
    rg_name      = "sahil-uat-rg1"
    vnet_name    = "sahilavnet-uat"
    subnet_name  = "AzureBastionSubnet"
    pip_name     = "bastionpip-uat"
    ip_configuration = { name = "bastion-ipconfig-uat" }
  }
}

nic_nsg_ids = {
  nic_nsg_1 = { nic_name = "sahilanic-uat", nsg_name = "sahilansg-uat", rg_name = "sahil-uat-rg1" }
  nic_nsg_2 = { nic_name = "secondnic-uat", nsg_name = "sahilansg-uat", rg_name = "sahil-uat-rg1" }
}

vms = {
  frontend = {
    vm_name = "frontendvm-uat"
    rg_name = "sahil-uat-rg1"
    location = "North Europe"
    vm_size = "Standard_B1s"
    admin_username = "frontendvm"
    admin_password = "Sahil@12345"
    nic_name = "sahilanic-uat"
    os_disk_caching = "ReadWrite"
    os_disk_storage_account_type = "Standard_LRS"
    vm_publisher = "Canonical"
    vm_offer = "0001-com-ubuntu-server-jammy"
    vm_sku = "22_04-lts"
    vm_version = "latest"
    custom_data = <<-EOT
      #!/bin/bash
      sudo apt update
      sudo apt upgrade -y
      sudo apt install -y nginx
      sudo rm -rf /var/www/html/*
      git clone https://github.com/devopsinsiders/StreamFlix.git /var/www/html/
      systemctl enable nginx
      systemctl start nginx
    EOT
  }
  backend = {
    vm_name = "backendvm-uat"
    rg_name = "sahil-uat-rg1"
    location = "North Europe"
    vm_size = "Standard_B1s"
    admin_username = "backendvm"
    admin_password = "Sahil@12345"
    nic_name = "secondnic-uat"
    os_disk_caching = "ReadWrite"
    os_disk_storage_account_type = "Standard_LRS"
    vm_publisher = "Canonical"
    vm_offer = "0001-com-ubuntu-server-focal"
    vm_sku = "20_04-lts"
    vm_version = "latest"
    custom_data = <<-EOT
      #!/bin/bash
      apt update -y
      apt upgrade -y
      apt install nginx -y
      rm -rf  /var/www/html/*
      git clone https://github.com/devopsinsiders/starbucks-clone.git /var/www/html/
      systemctl enable nginx
      systemctl start nginx
    EOT
  }
}

sql_servers = {
  server1 = {
    sqlservername                 = "sahilsqlserver1123-uat"
    rg_name                       = "sahil-uat-rg1"
    location                      = "North Europe"
    version                       = "12.0"
    server_login_username         = "server"
    server_login_password         = "Sahil@12345"
    public_network_access_enabled = true
  }
}

firewall_rules = {
  "server1-AllowIP1" = { server_id = "server1", name = "AllowIP1", start_ip_address = "10.0.17.62", end_ip_address = "10.0.17.62" }
  "server1-AllowIP2" = { server_id = "server1", name = "AllowIP2", start_ip_address = "49.43.131.11", end_ip_address = "49.43.131.11" }
}

sql_databases = {
  db1 = { name = "appdb", server_name = "sahilsqlserver1123-uat", resource_group = "sahil-uat-rg1", sku_name = "S0" }
  db2 = { name = "analyticsdb", server_name = "sahilsqlserver1123-uat", resource_group = "sahil-uat-rg1", sku_name = "S1", max_size_gb = 20, zone_redundant = false }
}

azurerm_lb_rb = {
  lb1 = {
    rg_name  = "sahil-uat-rg1"
    pip_name = "loadbalancerpip-uat"
    lb_name  = "sahil-loadbalancer-uat"
    location = "North Europe"
    sku      = "Standard"
    frontend_ip_config = [{ name = "sahil-frontend-ipconfig-uat" }]
  }
}

backend_ap_rb = {
  bap1 = { lb_name = "sahil-loadbalancer-uat", rg_name = "sahil-uat-rg1", backend_pool_name = "sahil-backend-pool-uat" }
}

nic_bp_association = {
  firstassociation  = { nic_name = "sahilanic-uat", nic_rg_name = "sahil-uat-rg1", lb_name = "sahil-loadbalancer-uat", rg_name = "sahil-uat-rg1", backend_address_pool_name = "sahil-backend-pool-uat", nic_ka_ip_config_name = "sahila-internal-uat" }
  secondassociation = { nic_name = "secondnic-uat", nic_rg_name = "sahil-uat-rg1", lb_name = "sahil-loadbalancer-uat", rg_name = "sahil-uat-rg1", backend_address_pool_name = "sahil-backend-pool-uat", nic_ka_ip_config_name = "second-internal-uat" }
}

lb_probe = {
  lb1 = { 
probe_name = "sahil-health-probe-uat"
probe_protocol = "Tcp"
probe_port = 80
rg_name = "sahil-uat-rg1"
lb_name = "sahil-loadbalancer-uat"
}
}

lb_rule = {
  lb1 = {
    lb_name                         = "sahil-loadbalancer-uat"
    rg_name                         = "sahil-uat-rg1"
    backend_address_pool_db_ka_name = "sahil-backend-pool-uat"
    lb_rule_name                    = "sahil-lb-rule-uat"
    protocol                        = "Tcp"
    frontend_port                   = 80
    backend_port                    = 80
    frontend_ip_configuration_name  = "sahil-frontend-ipconfig-uat"
    probe_name                      = "sahil-health-probe-uat"
  }
}
