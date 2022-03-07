terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "vm1dns" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "random_string" "vm2dns" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "azurerm_resource_group" "rv" {
 name     = var.resource_group_name_primary
 location = var.location-primary
 tags     = var.tags
}

resource "azurerm_resource_group" "rv-sec" {
 name     = var.resource_group_name_secondary
 location = var.location-secondary
 tags     = var.tags
}


resource "azurerm_virtual_network" "rv" {
 name                = "rv-vnet"
 address_space       = ["10.0.0.0/16"]
 location            = var.location-primary
 resource_group_name = azurerm_resource_group.rv.name
 tags                = var.tags
}

resource "azurerm_subnet" "rv" {
 name                 = "rv-subnet"
 resource_group_name  = azurerm_resource_group.rv.name
 virtual_network_name = azurerm_virtual_network.rv.name
 address_prefixes       = ["10.0.2.0/24"]
}

#VNET in Secondary region
resource "azurerm_virtual_network" "rv-sec" {
 name                = "rv-vnet-sec"
 address_space       = ["10.0.0.0/16"]
 location            = var.location-secondary
 resource_group_name = azurerm_resource_group.rv-sec.name
 tags                = var.tags
}

resource "azurerm_subnet" "rv-sec" {
 name                 = "rv-subnet"
 resource_group_name  = azurerm_resource_group.rv-sec.name
 virtual_network_name = azurerm_virtual_network.rv-sec.name
 address_prefixes       = ["10.0.2.0/24"]
}

#Public IP for VM1

resource "azurerm_public_ip" "vm1" {
 name                         = "vm1-public-ip"
 location                     = var.location-primary
 resource_group_name          = azurerm_resource_group.rv.name
 allocation_method            = "Static"
 domain_name_label            = "${random_string.vm1dns.result}-ssh"
 tags                         = var.tags
}

resource "azurerm_network_interface" "vm1" {
 name                = "vm1-nic"
 location            = var.location-primary
 resource_group_name = azurerm_resource_group.rv.name

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = azurerm_subnet.rv.id
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = azurerm_public_ip.vm1.id
 }

 tags = var.tags
}


resource "azurerm_storage_account" "rvstorage-primary" {
  name                     = "rvstorageeastus2"
  resource_group_name      = var.resource_group_name_primary
  location = var.location-primary
  account_tier             = "Standard"
  account_replication_type = "GRS"
    depends_on = [azurerm_resource_group.rv]

  tags = {
    environment = "storageaccount-primary"
  }
}

resource "azurerm_storage_account" "rvstorage-secondary" {
  name                     = "rvstoragecentralus"
  resource_group_name      = var.resource_group_name_secondary
  location = var.location-secondary
  account_tier             = "Standard"
  account_replication_type = "GRS"

  depends_on = [azurerm_resource_group.rv-sec]

  tags = {
    environment = "storageaccount-secondary"
  }
}

resource "azurerm_virtual_machine" "vm1" {
 name                  = "vm1"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.rv.name
 network_interface_ids = [azurerm_network_interface.vm1.id]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Canonical"
   offer     = "0001-com-ubuntu-server-focal"
   sku       = "20_04-lts-gen2"
   version   = "latest"
 }

 storage_os_disk {
   name              = "vm1-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }

 os_profile {
   computer_name  = "vm1"
   admin_username = var.admin_user
   admin_password = var.admin_password
   custom_data = file("web.conf")
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = var.tags
}

####Create VM2


resource "azurerm_public_ip" "vm2" {
 name                         = "vm2-public-ip"
 location                     = var.location-primary
 resource_group_name          = azurerm_resource_group.rv.name
 allocation_method            = "Static"
 domain_name_label            = "${random_string.vm2dns.result}-ssh"
 tags                         = var.tags
}

resource "azurerm_network_interface" "vm2" {
 name                = "vm2-nic"
 location            = var.location-primary
 resource_group_name = azurerm_resource_group.rv.name

 ip_configuration {
   name                          = "IPConfiguration"
   subnet_id                     = azurerm_subnet.rv.id
   private_ip_address_allocation = "dynamic"
   public_ip_address_id          = azurerm_public_ip.vm2.id
 }

 tags = var.tags
}


resource "azurerm_virtual_machine" "vm2" {
 name                  = "vm2"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.rv.name
 network_interface_ids = [azurerm_network_interface.vm2.id]
 vm_size               = "Standard_DS1_v2"

 storage_image_reference {
   publisher = "Canonical"
   offer     = "0001-com-ubuntu-server-focal"
   sku       = "20_04-lts-gen2"
   version   = "latest"
 }

 storage_os_disk {
   name              = "vm2-osdisk"
   caching           = "ReadWrite"
   create_option     = "FromImage"
   managed_disk_type = "Standard_LRS"
 }
 
 os_profile {
   computer_name  = "vm2"
   admin_username = var.admin_user
   admin_password = var.admin_password
   custom_data = file("web.conf")
 }

 os_profile_linux_config {
   disable_password_authentication = false
 }

 tags = var.tags
}

#Create Managed Disks
resource "azurerm_managed_disk" "disk1" {
  name                 = "vm1-data-disk1"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.rv.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk1" {
  managed_disk_id    = azurerm_managed_disk.disk1.id
  virtual_machine_id = azurerm_virtual_machine.vm1.id
  lun                = "10"
  caching            = "ReadWrite"
}

resource "azurerm_managed_disk" "disk2" {
  name                 = "vm2-data-disk"
 location              = var.location-primary
 resource_group_name   = azurerm_resource_group.rv.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 10
}

resource "azurerm_virtual_machine_data_disk_attachment" "disk2" {
  managed_disk_id    = azurerm_managed_disk.disk2.id
  virtual_machine_id = azurerm_virtual_machine.vm2.id
  lun                = "10"
  caching            = "ReadWrite"
}

# Create RV

resource "azurerm_recovery_services_vault" "vault" {
    name    = "recoveryvault-eastus12"
    location = var.location-primary
    resource_group_name = var.resource_group_name_primary
    sku     = "Standard"
    soft_delete_enabled = "false"
    depends_on = [azurerm_resource_group.rv]
}

resource "azurerm_backup_policy_vm" "policy" {
  name                = "vm-daily-backup-policy"
  resource_group_name = var.resource_group_name_primary
  recovery_vault_name = azurerm_recovery_services_vault.vault.name

backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 10
  }

  retention_weekly {
    count    = 42
    weekdays = ["Sunday", "Wednesday", "Friday", "Saturday"]
  }

  retention_monthly {
    count    = 7
    weekdays = ["Sunday", "Wednesday"]
    weeks    = ["First", "Last"]
  }

  retention_yearly {
    count    = 77
    weekdays = ["Sunday"]
    weeks    = ["Last"]
    months   = ["January"]
  }
}

resource "azurerm_backup_protected_vm" "vm" {
  resource_group_name = var.resource_group_name_primary
  recovery_vault_name = azurerm_recovery_services_vault.vault.name
  source_vm_id        = azurerm_virtual_machine.vm1.id
  backup_policy_id    = azurerm_backup_policy_vm.policy.id
}

#Create Backup Vault

resource "azurerm_data_protection_backup_vault" "backupvault" {
  name                = "backupvaulteastus2"
  location = var.location-primary
  resource_group_name = var.resource_group_name_primary
  datastore_type      = "VaultStore"
  redundancy          = "GeoRedundant"

  identity {
          type         = "SystemAssigned" 
        }
}

