# Configure Azure Active Directory Domain Service(ADDS) and Azure VMs (Windows and Linux)

# prerequisites are :
1. Azure Account
2. Registered Public Domain Name

# Deployment Output :

We have Two Main scripts 
1. Launchvminexistingdomain.ps1
2. azureADDS_integratewith_VMs.ps1

# 1.Launchvminexistingdomain.ps1 :
  This powershell script we are using, when we have pre-configure Azure Active Directory Domain Service and we want to add VMs into that domain.
  During deployment script will create 2 VMs (Windows and Linux) and configure Active Directory Domain Service (users).
  After successful installation we are able to login into VMs by using Azure Active Directory Domain Service users credential.
  
# 2.azureADDS_integratewith_VMs.ps1 :
  This powershell script we are using, when we want to creating Azure Active Directory Domain Service and add VMs into that Domain.
  
  During deployment script will create and configure (ADDS), with 2 VMs (Windows and Linux) and configure Active Directory Domain      Service (users) into that VMs.
  After successful installation we are able to login into VMs by using Azure Active Directory Domain Service users credential.
  
# Adding Custom Extention for Linux VM, to install Requird packages and configure ADDS 
  joinlinuxtoadds.sh : This Shell script install requird packages into Linux VM and configure Kerberose and System Security Services Daemon (SSSD).

# Login Process
After successful installation we are able to login into VMs by using Azure Active Directory Domain Service users credential.
