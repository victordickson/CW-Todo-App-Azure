terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.39.1"
    }
  }
}


provider "azurerm" {
  features {
    
  }
}

resource "azurerm_resource_group" "rg1" {
  name     = var.rg_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet1" {
  name                = "${var.vm_name}-network"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.rg1.name
}

resource "azurerm_subnet" "subnet1" {
  name                 = "${var.vm_name}-subnet"
  resource_group_name  = azurerm_resource_group.rg1.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = var.subnet_address_space
}

resource "azurerm_public_ip" "pip1" {
  name                = "${var.vm_name}-pip"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = var.location
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "main" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.subnet1.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.pip1.id
  }
}

resource "azurerm_virtual_machine" "vm1" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg1.name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = "Standard_D2s_v3"
  delete_os_disk_on_termination = true
  delete_data_disks_on_termination = true
  identity {
    type = "SystemAssigned"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password
    custom_data = data.template_file.userdata.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "/home/${var.admin_username}/.ssh/authorized_keys"
      key_data = data.azurerm_ssh_public_key.ssh_public_key.public_key

  }
}
}

data "azurerm_subscription" "current" {}

data "azurerm_role_definition" "contributor" {
  name = "Contributor"
}

resource "azurerm_role_assignment" "example" {
  scope              = data.azurerm_subscription.current.id
  role_definition_id = "${data.azurerm_subscription.current.id}${data.azurerm_role_definition.contributor.id}"
  principal_id       = azurerm_virtual_machine.vm1.identity[0].principal_id
}

data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = var.ssh_key_rg
  name                = var.ssh_key_name
}

data "template_file" "userdata" {
  template = file("${abspath(path.module)}/userdata.sh")
}

resource "azurerm_network_interface_security_group_association" "nic1" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.nsg1.id
}

resource "azurerm_network_security_group" "nsg1" {
    name                = "nsgwithsshopen"
    location            = var.location
    resource_group_name = azurerm_resource_group.rg1.name

    security_rule {
        name                       = "AllowSSH"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

security_rule {
        name                       = "AllowJenkins"
        priority                   = 120
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}
# resource "azurerm_virtual_machine_extension" "ssh" {

#   name                         = "ssh"
#   virtual_machine_id           = azurerm_virtual_machine.vm1.id
#   publisher                    = "Microsoft.Azure.Extensions"
#   type                         = "CustomScript"
#   type_handler_version         = "2.0"
#   settings = <<SETTINGS
#     {
#         "commandToExecute": "mkdir -p ~/.ssh && echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCYBkJ3y1tV6p8KApdM+Z97qYqO8QMTdL66B3ZRFA/MQ6q6FutPI4uyCTWbSB3z6vQU0OqfkJhSRElgUbBVM8aCa+we5CSa9Cr5AuM2MCJlelZTnfBAOUY1CaIRlvXB5jNLEplRpY2wnh2S6yRMbD72U6cE/zPW0Zc+0uu2ffzdy2wxhc0vAoLn3h5OwgZ1NoGsZMPQYZyPuxlfeShaC7EXqRDXvcRZKQktElnSQcyRN14glgt+AwYUFYF7vjxju2HnVsgJi8saPtEKvYETwkwmhs9KZJOavxI8+hveoSaFN5zMhuFIVDAo5G1LtmsDir7ibAGG4XZuuCMLhlGUxZLBJt7+AvG7AnjJnigBnAhaC1LGG3HKpkZ/YxQaZnv2vWiWqohD+FTY8uDzjug2eK0Y+hNyKoib1KfIClXoKfAINUn5RH5zxWxFsBALbVIcIR4hMY7Y0Ul5rE+eAOjai9VS7nkNci6QOO7tnbiS/VaZiqevlOrJJoGG0U2D37lLLKukNc1KXHAU108iL/TuA77s5NA/rQykOxn1LAlL8Z7LcUV6fKEg4NaXOxiCaC6zU1tZBy1okcSfOK0fSyw6Ymq2/QJsjdEIkdQz4SEyWotQLPLIPZKJHHle+NMyfm+7tkaINdm5FMYZi4bQ8L34ctgVXA2RRJuSZPE+p2y8qh8I5Q==' >> ~/.ssh/authorized_keys"
#     }
#   SETTINGS
# }


# ssh-keygen -t rsa -b 4096 -C "your_email@example.com"