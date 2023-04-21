terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.39.1"
    }
  }

  backend "azurerm" {
    resource_group_name  = "techcrux"
    storage_account_name = "satechcrux"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
    use_msi              = true
    subscription_id      = "d0d8f222-75d0xxxxxxxxxxxxxxxxxxxxxx"
    tenant_id            = "0d351a91-cxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }
}

provider "azurerm" {
  features {
  }

  use_msi         = true
  subscription_id      = "d0d8f222-75d0xxxxxxxxxxxxxxxxxxxxxx"
  tenant_id            = "0d351a91-cxxxxxxxxxxxxxxxxxxxxxxxxxx"
}

######################
### RESOURCE GROUP ###
######################
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

######################
### VNET & SUBNET ####
######################
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = [ "10.0.0.0/16" ]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [ "10.0.1.0/24" ]
}

########################
### VIRTUAL MACHINES ###
########################
resource "azurerm_virtual_machine" "vm" {
  count                            = 3
  name                             = element(var.vm_tags, count.index)
  location                         = azurerm_resource_group.rg.location
  resource_group_name              = azurerm_resource_group.rg.name
  network_interface_ids            = [ azurerm_network_interface.nic[count.index].id ]
  vm_size                          = "Standard_B1s"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  tags = {
    "name" = element(var.vm_tags, count.index)
    "environment" = "development"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [ azurerm_user_assigned_identity.identity.id ]
  }

  #   storage_image_reference {
  #   publisher = "RedHat"
  #   offer     = "RHEL"
  #   sku       = "8"
  #   version   = "latest"
  # }

    storage_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_2"
    version   = "latest"
  }
  storage_os_disk {
    name              = "${var.prefix}-osdisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = element(var.vm_tags, count.index)
    admin_username = var.admin_username
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = data.azurerm_ssh_public_key.ssh_public_key.public_key
    }
  }
}

resource "azurerm_network_interface" "nic" {
  count               = 3
  name                = "${var.prefix}-nic${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  depends_on = [
    azurerm_public_ip.pip
  ]

  ip_configuration {
    name                          = "IPConfiguration"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip[count.index].id
  }
}

resource "azurerm_public_ip" "pip" {
  count               = 3
  name                = "${var.prefix}-pip${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
}

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = var.ssh_key_rg
  name                = var.ssh_key_name
}

resource "azurerm_user_assigned_identity" "identity" {
  name                = "${var.prefix}-identity"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

data "azurerm_subscription" "primary" {
}

resource "azurerm_role_assignment" "role_assignment" {
  scope                = data.azurerm_subscription.primary.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.identity.principal_id
}

#########################
### NSG & ASSOCIATION ###
#########################
locals {
  inbound_ports_map = {
    "100" : "22", # If the key starts with a number, you must use the colon syntax ":" instead of "="
    "110" : "5000",
    "120" : "3000",
    "130" : "5432"
  }
}
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dynamic "security_rule" {
    for_each = local.inbound_ports_map
    iterator = item
    content {
      name                       = "Allow-${item.value}"
      priority                   = item.key
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = item.value
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  }
}
resource "azurerm_network_interface_security_group_association" "nic_association" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
