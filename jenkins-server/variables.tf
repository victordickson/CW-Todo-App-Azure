variable "rg_name" {
    default = "jenkins-rg"
}

variable "location" {
    default = "East US"
}

variable "vm_name" {
    default = "jenkins-server"
}

variable "vnet_address_space" {
    default = ["10.0.0.0/16"]
}

variable "subnet_address_space" {
    default = ["10.0.1.0/24"]
}

variable "admin_username" {
    default = "techcrux"
}

variable "admin_password" {
    default = "Password1234"
}

variable "ssh_key_name" {
    default = "techcrux"
}

variable "ssh_key_rg" {
    default = "techcrux"
}

variable "ssh_key_path" {
    default = "~/Documents/DevOps/Azure"
}









