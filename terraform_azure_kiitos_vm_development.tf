# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "3dd615b1-8926-4db2-bc8b-e1abce0cd8d5"
    client_id       = ""
    client_secret   = ""
    tenant_id       = "118e6137-7c71-4b80-af97-5b9b380f1aa2"
}

# Create a resource group if it doesn’t exist
resource "azurerm_resource_group" "KiitosDevelopResourceGroup" {
    name     = "kiitosDevelopResourceGroup"
    location = "westeurope"

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "KiitosDevelopNetwork" {
    name                = "kiitosNodeVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}

# Create subnet
resource "azurerm_subnet" "KiitosDevelopSubnet" {
    name                 = "kiitosNodeSubnet"
    resource_group_name  = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    virtual_network_name = "${azurerm_virtual_network.KiitosDevelopNetwork.name}"
    address_prefix       = "10.0.1.0/24"
}

# Create public IPs
resource "azurerm_public_ip" "KiitosDevelopPublicip" {
    name                         = "kiitosDevelopPublicIP"
    location                     = "westeurope"
    resource_group_name          = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    allocation_method            = "Dynamic"

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "KiitosDevelopnsg" {
    name                = "kiitosNodeNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTPS"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
      
    security_rule {
        name                       = "HTTP"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

	security_rule {
	    name                       = "Allow_outbound"
	    priority                   = 3000
	    direction                  = "Outbound"
	    access                     = "Allow"
	    protocol                   = "Tcp"
	    source_port_range          = "*"
	    destination_port_range     = "*"
	    source_address_prefix      = "*"
	    destination_address_prefix = "*"
	  }

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}

# Create network interface
resource "azurerm_network_interface" "KiitosDevelopnic" {
    name                      = "kiitosDevelopNIC"
    location                  = "westeurope"
    resource_group_name       = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    network_security_group_id = "${azurerm_network_security_group.KiitosDevelopnsg.id}"

    ip_configuration {
        name                          = "kiitosDevelopNicConfiguration"
        subnet_id                     = "${azurerm_subnet.KiitosDevelopSubnet.id}"
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = "${azurerm_public_ip.KiitosDevelopPublicip.id}"
    }

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}

# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    }
    
    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "KiitosDevelopstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    location                    = "westeurope"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}

# Create virtual machine
resource "azurerm_virtual_machine" "KiitosDevelopvm" {
    name                  = "KiitosVMDevelopment"
    location              = "westeurope"
    resource_group_name   = "${azurerm_resource_group.KiitosDevelopResourceGroup.name}"
    network_interface_ids = ["${azurerm_network_interface.KiitosDevelopnic.id}"]
    vm_size               = "Standard_DS1_v2"

    storage_os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }

    storage_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    os_profile {
        computer_name  = "kiitosdevelopserver"
        admin_username = "azureuser"
    }

    os_profile_linux_config {
        disable_password_authentication = true
        ssh_keys {
            path     = "/home/azureuser/.ssh/authorized_keys"
            key_data = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFK8Tod+9V5wa6RF44VfpdRYCgTTGQN1c9YBJUHkCU+knrO3r+fpZSLjO9ga7KPffHoL5WQkyvJQJ9H+ke+ISZH7xriUBO/fWaOBNsMtS+/NM2JnIrN2NHsHuZcGq45KnDGB6349OJ0riQWth6p2a/Lss3S2Mbvzu0u3/w9SclsrNtZ1cD7PiNJDJ5MLKB5YPydATvy8VwH71qfusDDYOI0MTlzmyBElVBhkcqeW1zzuXBtgbJOlQFLt6G8DcIXoZKAyeyXI+d1KH/cjk1/pWefnJsACl5muF8fI3Ee/OksxZmIVrlSo/RztpIw4PWOgpE29ksKtMeYSjNgNIkMhh9 admin@clluc.com"
        }
    }

    boot_diagnostics {
        enabled = "true"
        storage_uri = "${azurerm_storage_account.KiitosDevelopstorageaccount.primary_blob_endpoint}"
    }

    tags = {
        environment = "Kiitos Develop (Test)"
    }
}