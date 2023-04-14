variable "prefix" {
  default = "phonebook"
}

variable "backend_rg_name" {
  default = "techcrux"
}

variable "backend_sa_name" {
  default = "techcrux2"
}

variable "backend_container_name" {
  default = "tfstate"
}

variable "location" {
  default = "eastus"
}

variable "admin_username" {
  default = "clouduser"
}

variable "ssh_key_rg" {
  default = "techcrux"
}

variable "ssh_key_name" {
  default = "techcrux"
}

variable "vm_tags" {
  default = ["postgresql", "nodejs", "react"]
}