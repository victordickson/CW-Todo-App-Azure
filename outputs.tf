output "react_ip" {
  value = "http://${azurerm_public_ip.pip[2].ip_address}:3000"
}

output "nodejs_public_ip" {
  value = azurerm_public_ip.pip[1].ip_address
}

output "postgresql_private_ip" {
  value = azurerm_network_interface.nic[0].private_ip_address
}