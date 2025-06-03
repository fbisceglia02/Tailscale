terraform {
  backend "azurerm" {
    resource_group_name   = "my-tfstate-rg"
    storage_account_name  = "mytfstatestorageferrux"
    container_name        = "tfstate"
    key                   = "Tailscale/dev/terraform.tfstate"
  }
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.31.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# RESOURCE GROUP
resource "azurerm_resource_group" "main" {
  name     = "rg-ts-demo"
  location = "westeurope"
}

# VNET1
resource "azurerm_virtual_network" "vnet1" {
  name                = "vnet1"
  address_space       = ["10.10.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "vnet1_subnet1" {
  name                 = "vnet1-subnet1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.10.0.0/24"]
}

resource "azurerm_subnet" "vnet1_subnet2" {
  name                 = "vnet1-subnet2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.10.1.0/24"]
}

# VNET2
resource "azurerm_virtual_network" "vnet2" {
  name                = "vnet2"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "vnet2_subnet1" {
  name                 = "vnet2-subnet1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "vnet2_subnet2" {
  name                 = "vnet2-subnet2"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.0.1.0/24"]
}

# =========== PUBLIC IP ==============
resource "azurerm_public_ip" "vnet1_" {
  name                = "vnet1-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_public_ip" "vnet2_" {
  name                = "vnet2-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}


# =========== VIRTUAL MACHINES ==============
# Shared image for Ubuntu
variable "ubuntu_image" {
  default = {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# NSG is optional, but recommended in real deployments

# VNET1 - vm-test3 (Subnet 1, Static IP)
resource "azurerm_network_interface" "vnet1_vmtsst3_nic" {
  name                = "nic-vm-test3"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vnet1_subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.10.0.4"
    public_ip_address_id          = azurerm_public_ip.vnet1_.id
  }
}

resource "azurerm_linux_virtual_machine" "vnet1_vmtsst3" {
  name                = "vm-test3"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.vnet1_vmtsst3_nic.id]

  admin_password = "ChangeMe123!"  # Replace for production
  disable_password_authentication = false

  source_image_reference {
    publisher = var.ubuntu_image.publisher
    offer     = var.ubuntu_image.offer
    sku       = var.ubuntu_image.sku
    version   = var.ubuntu_image.version
  }

  os_disk {
    name              = "disk-vm-test3"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# VNET1 - vm-ts-03 (Subnet 2, Public IP, Minikube host)
resource "azurerm_public_ip" "vnet1_vmts_p3_pip" {
  name                = "pip-vm-ts-03"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "vnet1_vmts_p3_nic" {
  name                = "nic-vm-ts-03"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vnet1_subnet2.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vnet1_vmts_p3_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "vnet1_vmts_p3" {
  name                = "vm-ts-03"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.vnet1_vmts_p3_nic.id]

  admin_password = "ChangeMe123!"  # Replace for production
  disable_password_authentication = false

  source_image_reference {
    publisher = var.ubuntu_image.publisher
    offer     = var.ubuntu_image.offer
    sku       = var.ubuntu_image.sku
    version   = var.ubuntu_image.version
  }

  os_disk {
    name              = "disk-vm-ts-03"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  # For Minikube, cloud-init or custom script extension can go here
  # Uncomment and customize if needed:
  # custom_data = filebase64("init-minikube.sh")
}

# VNET2 - vm-ts-01 (Vnet 2, Subnet 1, Static IP - public ip)
resource "azurerm_network_interface" "vnet2_vmts_p1_nic" {
  name                = "nic-vm-ts-01"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vnet2_subnet1.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4"
    public_ip_address_id          = azurerm_public_ip.vnet2_.id
  }
}

# resource "azurerm_public_ip" "vnet2_" {

resource "azurerm_linux_virtual_machine" "vnet2_vmts_p1" {
  name                = "vm-ts-01"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.vnet2_vmts_p1_nic.id]

  admin_password = "ChangeMe123!"  # Replace for production
  disable_password_authentication = false

  source_image_reference {
    publisher = var.ubuntu_image.publisher
    offer     = var.ubuntu_image.offer
    sku       = var.ubuntu_image.sku
    version   = var.ubuntu_image.version
  }

  os_disk {
    name              = "disk-vm-ts-01"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}

# VNET2 - VM-TS-02 (Subnet 2, Static IP)
resource "azurerm_network_interface" "vnet2_vmts_02_nic" {
  name                = "nic-vm-ts-02"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vnet2_subnet2.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
  }
}

resource "azurerm_linux_virtual_machine" "vnet2_vmts_02" {
  name                = "vm-ts-02"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = "azureuser"
  network_interface_ids = [azurerm_network_interface.vnet2_vmts_02_nic.id]

  admin_password = "ChangeMe123!"  # Replace for production
  disable_password_authentication = false

  source_image_reference {
    publisher = var.ubuntu_image.publisher
    offer     = var.ubuntu_image.offer
    sku       = var.ubuntu_image.sku
    version   = var.ubuntu_image.version
  }

  os_disk {
    name              = "disk-vm-ts-02"
    caching           = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
}


# NSG
resource "azurerm_network_security_group" "ssh" {
  name                = "nsg-allow-ssh"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allow-ssh"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG to NIC attachment 

resource "azurerm_network_interface_security_group_association" "vm1" {
  network_interface_id      = azurerm_network_interface.vnet1_vmtsst3_nic.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

resource "azurerm_network_interface_security_group_association" "vm-ts-01" {
  network_interface_id      = azurerm_network_interface.vnet2_vmts_p1_nic.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

resource "azurerm_network_interface_security_group_association" "vm-ts-02" {
  network_interface_id      = azurerm_network_interface.vnet2_vmts_02_nic.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}

resource "azurerm_network_interface_security_group_association" "vm-ts-03" {
  network_interface_id      = azurerm_network_interface.vnet1_vmts_p3_nic.id
  network_security_group_id = azurerm_network_security_group.ssh.id
}



# ========= OUTPUTS (Optional, for connection info) =========



output "vnet1_vmtsst3_ip" {
  value = azurerm_network_interface.vnet1_vmtsst3_nic.private_ip_address
}

output "vnet2_vmts_p1_ip" {
  value = azurerm_network_interface.vnet2_vmts_p1_nic.private_ip_address
}

output "vnet2_vmts_02_ip" {
  value = azurerm_network_interface.vnet2_vmts_02_nic.private_ip_address
}



output "vnet1_vmts_p3_public_ip" {
  value = azurerm_public_ip.vnet1_vmts_p3_pip.ip_address
}

output "vnet1_vnet1_public_ip" {
  value = azurerm_public_ip.vnet1_.ip_address
}

output "vnet1_vnet2_public_ip" {
  value = azurerm_public_ip.vnet2_.ip_address
}

