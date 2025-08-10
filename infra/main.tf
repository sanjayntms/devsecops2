terraform {
  backend "azurerm" {
    resource_group_name   = var.resource_group_name
    storage_account_name  = var.storage_account_name
    container_name        = "tfstate"
    key                   = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

variable "resource_group_name" { type = string }
variable "storage_account_name" { type = string }
variable "keyvault_name" { type = string }
variable "location" { type = string }

#resource "azurerm_resource_group" "rg" {
#  name     = var.resource_group_name
#  location = var.location
#}


data "azurerm_resource_group" "rg" {
  name = "vm-devsecops-rg"
 }
data "azurerm_key_vault" "kv" {
  name                        = var.keyvault_name
  resource_group_name         = data.azurerm_resource_group.rg.name
 
}

data "azurerm_key_vault_secret" "vm_password" {
  name         = "webvm-password"
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_virtual_network" "vnet" {
  name                = "web-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "websubnet" {
  name                 = "web-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "webvm" {
  name                = "webvm-pip"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_network_interface" "nic" {
  name                = "webvm-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.websubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webvm.id
  }
}

resource "azurerm_linux_virtual_machine" "webvm" {
  name                = "webvm"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B1s"
  admin_username      = "vmadmin"
  admin_password      = data.azurerm_key_vault_secret.vm_password.value
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

