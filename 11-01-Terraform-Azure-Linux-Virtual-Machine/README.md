---
title: Provision Azure Linux VM using Terraform
description: Learn to Provision Azure Linux VM using Terraform
---

## Step-01: Introduction
- We will create the below Azure Resources using Terraform
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnet
4. Azure Public IP
5. Azure Network Interface
6. [Azure Linux Virtual Machine](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine)
7. `random_string` Resource
- We will use Azure `custom_data` argument in `azurerm_linux_virtual_machine` to install a simple webserver during the creation of VM.
- [Terraform file Function](https://www.terraform.io/docs/language/functions/file.html)
- [Terraform filebase64 Function](https://www.terraform.io/docs/language/functions/filebase64.html)

## Step-02: Create SSH Keys for Azure Linux VM
```t
# Create Folder
cd terraform-manifests/
mkdir ssh-keys

# Create SSH Key
cd ssh-ekys
ssh-keygen \
    -m PEM \
    -t rsa \
    -b 4096 \
    -C "azureuser@myserver" \
    -f terraform-azure.pem 
Important Note: If you give passphrase during generation, during everytime you login to VM, you also need to provide passphrase.

# List Files
ls -lrt ssh-keys/

# Files Generated after above command 
Public Key: terraform-azure.pem.pub -> Rename as terraform-azure.pub
Private Key: terraform-azure.pem

# Permissions for Pem file
chmod 400 terraform-azure.pem

## Permission using powershell to all users
icacls "terraform-azure.pem" /inheritance:r /grant:r "Everyone:(R)"
### Below one is more approprivate than above one #####
icacls ./ssh-keys/terraform-azure.pem /inheritance:r /grant:r "$($env:USERNAME):(R)" /remove "Everyone"

########### Authorized keys will present in below location #############
/home/azureuser/.ssh/authorized_keys

```  

## Step-03: c1-versions.tf - Create Terraform & Provider Blocks 
- Create Terraform Block
- Create Provider Block
- Create Random Resource Block
```t
# Terraform Block
terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.0" 
    }
    random = {
      source = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Provider Block
provider "azurerm" {
 features {}          
}
##############
You can use below one as well. If you are faing Error: subscription_id is a required provider property when performing a plan/apply operation

provider "azurerm" {
  features {}
  use_cli = true
}

# Random String Resource
resource "random_string" "myrandom" {
  length = 6
  upper = false 
  special = false
  number = false   
}
```
## Step-04: c2-resource-group.tf
```t
# Resource-1: Azure Resource Group
resource "azurerm_resource_group" "myrg" {
  name = "myrg-1"
  location = "East US"
}
```

## Step-05: c3-vritual-network.tf - Virtual Network Resource
```t
# Create Virtual Network
resource "azurerm_virtual_network" "myvnet" {
  name                = "myvnet-1"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name
}
```

## Step-06: c3-vritual-network.tf  - Azure Subnet Resource
```t
# Create Subnet
resource "azurerm_subnet" "mysubnet" {
  name                 = "mysubnet-1"
  resource_group_name  = azurerm_resource_group.myrg.name
  virtual_network_name = azurerm_virtual_network.myvnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
```
## Step-07: c3-vritual-network.tf  - Azure Public IP Resource
```t

# Create Public IP Address
resource "azurerm_public_ip" "mypublicip" {
  name                = "mypublicip-1"
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  allocation_method   = "Static"
  domain_name_label = "app1-vm-${random_string.myrandom.id}"
  tags = {
    environment = "Dev"
  }
}
``` 
## Step-08: c3-vritual-network.tf  - Network Interface Resource
```t

# Create Network Interface
resource "azurerm_network_interface" "myvmnic" {
  name                = "vmnic"
  location            = azurerm_resource_group.myrg.location
  resource_group_name = azurerm_resource_group.myrg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mysubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.mypublicip.id 
  }
}
```

## Step-09: c4-linux-virtual-machine.tf
```t
# Resource: Azure Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "mylinuxvm" {
  name                = "mylinuxvm-1"
  computer_name       = "devlinux-vm1" # Hostname of the VM
  resource_group_name = azurerm_resource_group.myrg.name
  location            = azurerm_resource_group.myrg.location
  size                = "Standard_DS1_v2"
  admin_username      = "azureuser"
  network_interface_ids = [
    azurerm_network_interface.myvmnic.id
  ]
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("${path.module}/ssh-keys/terraform-azure.pub")
  }
  os_disk {
    name = "osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "83-gen2"
    version   = "latest"
  }
  custom_data = filebase64("${path.module}/app-scripts/app1-cloud-init.txt")
}
```

In the Terraform code snippet, the public SSH key is being used to provision the Azure Linux VM. The reason for using the public key during VM provisioning rather than the private key lies in how SSH key-based authentication works.

SSH Key Authentication Overview
SSH key-based authentication uses a key pair: a public key and a private key.
The public key is placed on the server (in this case, the Azure Linux VM).
The private key is kept securely on the client machine (the machine from which you connect to the VM).
When the client attempts to connect to the VM, the private key is used to authenticate the connection, and the server (VM) uses the public key to verify that the private key matches it

## Step-10: app1-cloud-init.txt
```t
#cloud-config
package_upgrade: false
packages:
  - httpd
write_files:
  - owner: root:root 
    path: /var/www/html/index.html
    content: |
      <h1>Welcome to StackSimplify - APP-1</h1>
  - owner: root:root 
    path: /var/www/html/app1/index.html
    content: |
      <!DOCTYPE html> <html> <body style="background-color:rgb(250, 210, 210);"> <h1>Welcome to Stack Simplify - APP-1</h1> <p>Terraform Demo</p> <p>Application Version: V1</p> </body></html>      
runcmd:
  - sudo systemctl start httpd  
  - sudo systemctl enable httpd
  - sudo systemctl stop firewalld
  - sudo mkdir /var/www/html/app1 
  - [sudo, curl, -H, "Metadata:true", --noproxy, "*", "http://169.254.169.254/metadata/instance?api-version=2020-09-01", -o, /var/www/html/app1/metadata.html]
```

## Step-11: Execute Terraform commands to Create Resources using Terraform
```t
# Initialize Terraform
terraform init

# Terraform Validate
terraform validate

# Terraform Plan 
terraform plan

# Terraform Apply 
terraform apply 
```

## Step-12: Verify the Resources
- Verify Resources
1. Azure Resource Group
2. Azure Virtual Network
3. Azure Subnet
4. Azure Public IP
5. Azure Network Interface
6. Azure Virtual Machine
```t
# Connect to VM and Verify 
ssh -i ssh-keys/terraform-azure.pem azureuser@<PUBLIC-IP>

# Access Application
http://<PUBLIC_IP>
http://<PUBLIC_IP>/app1
http://<PUBLIC_IP>/app1/metadata.html
```


## Step-13: Destroy Terraform Resources
```t
# Destroy Terraform Resources
terraform destroy

# Remove Terraform Files
rm -rf .terraform*
rm -rf terraform.tfstate*
```
ssh-keygen \
    -m PEM \
    -t rsa \
    -b 4096 \
    -C "azureuser@myserver" \
    -f terraform-azure.pem
1. ssh-keygen:
This is the command to generate an SSH key pair. SSH key pairs consist of a public and private key, which are used for secure authentication.

2. -m PEM:
This flag specifies the format of the key file.
PEM stands for Privacy-Enhanced Mail, which is a base64 encoded format for key files.
By default, ssh-keygen generates the private key in OpenSSH format (since OpenSSH 7.8), but some applications (such as older SSH versions or other tools) may require the key to be in the PEM format, which is why this flag is used.
3. -t rsa:
This specifies the type of the key to be generated. In this case, rsa refers to the RSA algorithm.
RSA (Rivest-Shamir-Adleman) is a widely used public-key cryptosystem. This command generates an RSA key pair.
4. -b 4096:
This flag specifies the number of bits in the key.
4096 bits is considered a very strong level of encryption, offering greater security than the default value of 2048 bits.
The higher the number of bits, the more computationally expensive the encryption process is, but it’s also more secure.
5. -C "azureuser@myserver":
The -C option is used to add a comment to the key, which is useful for identifying keys later.
In this case, the comment is "azureuser@myserver", meaning the key is for the user "azureuser" logging into a server identified as "myserver."
This comment appears at the end of the public key when viewed, but does not affect its functionality.
6. -f terraform-azure.pem:
This flag specifies the filename where the private key will be saved.
The name terraform-azure.pem is provided, which means:
The private key will be saved in a file called terraform-azure.pem.
By default, the corresponding public key will be saved in a file called terraform-azure.pem.pub in the same location.
The .pem extension indicates the file is in the PEM format, as specified by the -m PEM flag.
Summary:
This command generates a 4096-bit RSA key pair, with the private key saved in PEM format in the file terraform-azure.pem. The public key will be saved in a separate file terraform-azure.pem.pub. The key includes a comment "azureuser@myserver" for identification purposes. This could be useful in cloud deployments such as Azure (especially when using Terraform to manage infrastructure), where the SSH key is used to authenticate the user azureuser to a server named myserver.

ssh -i ./ssh-keys/terraform-azure.pem azureuser@172.191.44.68


########## AZ Login issues ######
If az login having issues use az login --use-device-code
az --version
az account clear
az account list
az account set --subscription="SUBSCRIPTION_ID"
az account show

## References 
1. [Azure Resource Group](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group)
2. [Azure Virtual Network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network)
3. [Azure Subnet](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet)
4. [Azure Public IP](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip)
5. [Azure Network Interface](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface)
6. [Azure Virtual Machine](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_virtual_machine)
