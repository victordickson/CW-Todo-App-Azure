output "ip_address" {
  value = azurerm_public_ip.pip1.ip_address
}

output "SSH_Command" {
  value = "ssh -i ${var.ssh_key_path}/${var.ssh_key_name}.pem ${var.admin_username}@${azurerm_public_ip.pip1.ip_address}"
}