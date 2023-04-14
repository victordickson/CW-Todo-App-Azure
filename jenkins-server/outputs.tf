output "URL" {
  value = "http://${azurerm_public_ip.pip.ip_address}:8080"
}

output "SSH_Command" {
  value = "ssh -i ${var.ssh_private_key_path}/${var.ssh_key_name}.pem ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}

output "Jenkins_Password_Retrieval" {
  value = "sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}