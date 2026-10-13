terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# Le "dossier" qui contient tout le projet
resource "azurerm_resource_group" "rg" {
  name     = "rg-projet-devops-tf"
  location = var.region
}

# Le réseau privé et son sous-réseau
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-projet-devops"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-projet-devops"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# L'adresse IP publique, fixe
resource "azurerm_public_ip" "ip" {
  name                = "pip-projet-devops"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Le pare-feu d'Azure : seulement SSH (22) et HTTP (80)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-projet-devops"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
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
    name                       = "HTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# La carte réseau, reliée au sous-réseau et à l'IP publique
resource "azurerm_network_interface" "nic" {
  name                = "nic-projet-devops"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "nic_nsg" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# La machine virtuelle
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "vm-projet-devops"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  size                  = var.vm_size
  admin_username        = "ayoub"
  network_interface_ids = [azurerm_network_interface.nic.id]

  admin_ssh_key {
    username   = "ayoub"
    public_key = file("~/.ssh/azure_devops.pub")
  }
  
  admin_ssh_key {
    username   = "ayoub"
    public_key = file("~/.ssh/github_deploy.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 64 # taille P6, incluse dans l'offre gratuite
  }

  # Ubuntu Server 24.04 LTS, la version gratuite (pas "Pro")
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}