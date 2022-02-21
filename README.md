# azure-recoveryvault
Terraform code for Azure to build below components.
1. Two Resource Groups in EASTUS2 & CentralUS
2. VNET/Subnet/Public IP/DNS String
3. Two storage Accounts, one in each region to be used as staging area for VM restores
4. Recovery Services Vault with Daily VM Backup Policy and Retention 
5. Two Ubuntu 20.04 LTS VMs with Data Disks
6. Install htop/nginx and deploy public SSH key onto the VMs
7. Protect/Backup one VM with recovery services vault with Daily VM Backup Policy
 
Code is working without any warnings or errors and I have tested this code multiple times. 
