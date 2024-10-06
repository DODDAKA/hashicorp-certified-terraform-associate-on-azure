Hi,
I have infra requirement on Azure as below. Please give terraform code using azurerm provider.

Location: east us2.
rg: prod, dev, qa
In each environment I have 5 vms each and they are not identical because each vm have diffferent sku.

please give code.
Adding more information:
Each image is different.

########################
Variable.tf
########################
variable "location" {
  description = "Azure region"
  type        = string
  default     = "East US 2"
}

variable "resource_groups" {
  description = "List of resource groups"
  type        = list(string)
  default     = ["prod", "dev", "qa"]
}

variable "vm_sizes" {
  description = "Map of VM sizes for each environment"
  type        = map(list(string)
  default = {
    prod = ["Standard_DS1_v2", "Standard_DS2_v2", "Standard_B2s", "Standard_D3s_v2", "Standard_F2s"]
    dev  = ["Standard_B1s", "Standard_B2s", "Standard_DS1_v2", "Standard_D2s_v3", "Standard_F1"]
    qa   = ["Standard_A1_v2", "Standard_A2_v2", "Standard_DS1_v2", "Standard_B2ms", "Standard_D3_v2"]
  })
}

variable "image_references" {
  description = "Map of image details for each environment"
  type        = map(list(map(string)))
  default = {
    prod = [
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" },
      { publisher = "Canonical", offer = "UbuntuLTS", sku = "18.04-LTS" },
      { publisher = "MicrosoftSQLServer", offer = "SQL2019", sku = "2019-Standard" },
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" },
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" }
    ]
    dev = [
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" },
      { publisher = "Canonical", offer = "UbuntuLTS", sku = "18.04-LTS" },
      { publisher = "MicrosoftSQLServer", offer = "SQL2019", sku = "2019-Standard" },
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" },
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" }
    ]
    qa = [
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" },
      { publisher = "Canonical", offer = "UbuntuLTS", sku = "18.04-LTS" },
      { publisher = "MicrosoftSQLServer", offer = "SQL2019", sku = "2019-Standard" },
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" },
      { publisher = "MicrosoftWindowsServer", offer = "WindowsServer", sku = "2019-Datacenter" }
    ]
  }
}

#############################
main.tf
#############################

provider "azurerm" {
  features {}
}

# Create Resource Groups
resource "azurerm_resource_group" "rg" {
  for_each = toset(var.resource_groups)
  name     = each.key
  location = var.location
}

# Create Virtual Networks and Subnets
resource "azurerm_virtual_network" "vnet" {
  for_each            = toset(var.resource_groups)
  name                = "${each.key}-vnet"
  address_space       = ["10.${index(var.resource_groups, each.key)}.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[each.key].name
}

resource "azurerm_subnet" "subnet" {
  for_each            = toset(var.resource_groups)
  name                = "${each.key}-subnet"
  resource_group_name = azurerm_resource_group.rg[each.key].name
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes    = ["10.${index(var.resource_groups, each.key)}.1.0/24"]
}

# Create Virtual Machines
resource "azurerm_windows_virtual_machine" "vm" {
  for_each = toset(var.resource_groups)
  count    = 5

  name                = "${each.key}-vm-${count.index + 1}"
  resource_group_name = azurerm_resource_group.rg[each.key].name
  location            = var.location
  size                = var.vm_sizes[each.key][count.index]
  admin_username      = "adminuser"
  admin_password      = "P@ssword1234!"  # Use a secure password

  network_interface_ids = [azurerm_network_interface.nic[each.key][count.index].id]

  os_disk {
    caching       = "ReadWrite"
    create_option = "FromImage"
  }

  source_image_reference {
    publisher = var.image_references[each.key][count.index].publisher
    offer     = var.image_references[each.key][count.index].offer
    sku       = var.image_references[each.key][count.index].sku
    version   = "latest"
  }
}

# Create Network Interfaces
resource "azurerm_network_interface" "nic" {
  for_each = toset(var.resource_groups)
  count    = 5

  name                = "${each.key}-nic-${count.index + 1}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg[each.key].name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet[each.key].id
    private_ip_address_allocation = "Dynamic"
  }
}

