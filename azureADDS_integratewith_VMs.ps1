########################################################################
#    Create Azure Active Directory Domain serice and add the VMs       #
#          Into that Directory using Power shell scripting             #
#          Created by Sangam                                           #
########################################################################
# Change the following values to match your deployment.
$AaddsAdminUserUpn = "sangaml@sangamlonkar14.cf"
$AzureSubscriptionId = "8c879d4b-1e31-438b-8f74-41093d5c4b83"
$ManagedDomainName = "sangamlonkar14.cf"
$ResourceGroupName = "finalrg"
$VnetName = "DomainServicesVNet"
$location = "westus"

###Add user
$SecurePassword=ConvertTo-SecureString 'Lkjhg5fdsa@' –asplaintext –force

new-AzureRmADUser -DisplayName "lucky" -UserPrincipalName "lucky@sangamlonkar14.cf" -Password $SecurePassword -MailNickname "lucky"
#>
# Connect to your Azure AD directory.
#Connect-AzureAD

# Login to your Azure subscription.
#Connect-AzureRmAccount

# Create the service principal for Azure AD Domain Services.
#New-AzurermADServicePrincipal -AppId “54e05464-a580-48eb-8e7b-a50da31cf07a”
New-AzurermADServicePrincipal

# Create the delegated administration group for AAD Domain Services.
New-AzurermADGroup -DisplayName "Admingroup4" -MailNickName "AADDCAdministrators"

# First, retrieve the object ID of the newly created 'AAD DC Administrators' group.
$GroupObjectId = Get-AzurermADGroup -DisplayNameStartsWith 'Admingroup4' | Select-Object Id

# Now, retrieve the object ID of the user you'd like to add to the group.
$UserObjectId = Get-AzurermADUser -UserPrincipalName "$AaddsAdminUserUpn" | Select-Object Id

# Add the user to the 'AAD DC Administrators' group.
Add-AzurermADGroupMember -MemberObjectId $UserObjectId.Id -TargetGroupObjectId $GroupObjectId.Id 

# Register the resource provider for Azure AD Domain Services with Resource Manager.
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.AAD

# #Create the resource group.
New-AzureRmResourceGroup `
  -Name $ResourceGroupName `
  -Location $location
#
# Create the dedicated subnet for AAD Domain Services.
$AaddsSubnet = New-AzureRmVirtualNetworkSubnetConfig `
  -Name DomainServices `
  -AddressPrefix 10.0.0.0/24

$WorkloadSubnet = New-AzureRmVirtualNetworkSubnetConfig `
  -Name Workloads `
  -AddressPrefix 10.0.1.0/24

# Create the virtual network in which you will enable Azure AD Domain Services.
$Vnet=New-AzureRmVirtualNetwork `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -Name $VnetName `
  -AddressPrefix 10.0.0.0/16 `
  -Subnet $AaddsSubnet,$WorkloadSubnet

  Write-Host "----- Deployinging Azuure AD DS Service -----" -ForegroundColor Green
  Write-Host "----- Deployinging Azuure AD DS Service take Around 60 Min -----" -ForegroundColor Green

# Enable Azure AD Domain Services for the directory.
New-AzureRmResource -ResourceId "/subscriptions/$AzureSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AAD/DomainServices/$ManagedDomainName" `
  -Location $location `
  -Properties @{"DomainName"=$ManagedDomainName; `
    "SubnetId"="/subscriptions/$AzureSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$VnetName/subnets/DomainServices"} `
  -ApiVersion 2017-06-01 -Force -Verbose
#>
Write-Host "----- Deployinging Azuure AD DS Service -----" -ForegroundColor Green
########################################################################
#                                                                      #
#          Launching Windows VM                                        #
#                                                                      #
########################################################################
Write-Host "----- Launching Windows VM -----" -ForegroundColor Green

# Create a public IP address and specify a DNS name
$winpip = New-AzureRmPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "winpublicdns$(Get-Random)"

#Create a network security group and a network security group rule
# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
  -Name myNetworkSecurityGroupRuleRDP `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 1000 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 3389 `
  -Access Allow

# Create a network security group
$winnsg = New-AzureRmNetworkSecurityGroup `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -Name myNetworkSecurityGroup `
  -SecurityRules $nsgRuleRDP

  #Create a network card for the virtual machine
# Create a virtual network card and associate it with public IP address and NSG
$winnic = New-AzureRmNetworkInterface `
  -Name "winmyNic" `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -SubnetId $Vnet.Subnets[0].Id `
  -PublicIpAddressId $winpip.Id `
  -NetworkSecurityGroupId $winnsg.Id
#Create a virtual machine

# Define a credential object to store the username and password for the virtual machine
$UserName='demouser'
$Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($UserName,$Password)

# Create the virtual machine configuration object
$winVmName = "WinVirtualMachine"
$VmSize = "Standard_A1"
$winVirtualMachine = New-AzureRmVMConfig `
  -VMName $winVmName `
  -VMSize $VmSize

$winVirtualMachine = Set-AzureRmVMOperatingSystem `
  -VM $winVirtualMachine `
  -Windows `
  -ComputerName "MainComputer" `
  -Credential $Credential

$winVirtualMachine = Set-AzureRmVMSourceImage `
  -VM $winVirtualMachine `
  -PublisherName "MicrosoftWindowsServer" `
  -Offer "WindowsServer" `
  -Skus "2016-Datacenter" `
  -Version "latest" | `
  Add-AzureRmVMNetworkInterface -Id $winnic.Id

# Create the virtual machine.
New-AzureRmVM `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -VM $winVirtualMachine

    Write-Host "----- Launched Windows VM Successfully!!-----" -ForegroundColor Green
    Get-AzureRmVM -ResourceGroupName $RG | Where-Object {$_.Name -like 'WinVirtualMachine'} |
    Add-JDAzureRMVMToDomain -DomainName sangamlonkar14.cf -Verbose
    function Add-JDAzureRMVMToDomain {
    
    param(
       [Parameter(Mandatory=$true)]
       [string]$DomainName,
       [Parameter(Mandatory=$false)]
       [System.Management.Automation.PSCredential]$Credentials = (Get-Credential -Message 'Enter the domain join credentials'),
       [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
       [Alias('VMName')]
       [string]$Name,
       [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
       [ValidateScript({Get-AzureRmResourceGroup -Name $_})]
       [string]$ResourceGroupName
    )
       begin {
           #Define domain join settings (username/domain/password)
           $Settings = @{
               Name = $DomainName
               User = $Credentials.UserName
               Restart = "true"
               Options = 3
           }
           $ProtectedSettings =  @{
                   Password = $Credentials.GetNetworkCredential().Password
           }
           Write-Verbose -Message "Domainname is: $DomainName"
       }
       process {
           try {
               $RG = Get-AzureRmResourceGroup -Name $ResourceGroupName
               $JoinDomainHt = @{
                   ResourceGroupName = $RG.ResourceGroupName
                   ExtensionType = 'JsonADDomainExtension'
                   Name = 'joindomain'
                   Publisher = 'Microsoft.Compute'
                   TypeHandlerVersion = '1.0'
                   Settings = $Settings
                   VMName = $Name
                   ProtectedSettings = $ProtectedSettings
                   Location = $RG.Location
               }
               Write-Verbose -Message "Joining $Name to $DomainName"
               Set-AzureRMVMExtension @JoinDomainHt
               Start-Sleep 360
    
             Set-AzureRmVMCustomScriptExtension -ResourceGroupName $RG `
                   -VMName $Name -Name "myCustomScript" `
                   -FileUri "https://raw.githubusercontent.com/sangaml/adds_win_Linux/master/userpermission.ps1" `
                   -Run "userpermission.ps1" `
                   -Location "west us"
           } catch {
               Write-Warning $_
           }
       }
       end { }
    }
    
    ########################################################################
#                                                                      #
#          Launching Linux VM                                          #
#                                                                      #
########################################################################
Write-Host "----- Launching Linux VM -----" -ForegroundColor Green

# Create variables to store the location and resource group names.
$random = (New-Guid).ToString().Substring(0,8)
# Create variables to store the storage account name and the storage account SKU information
$StorageAccountName = "linuxstorageaccount$random"
$SkuName = "Standard_LRS"

# Create variables to store the network security group and rules names.
$nsgName = "LinuxNetworkSecurityGroup"
$nsgRuleSSHName = "NetworkSecurityGroupRuleSSH"

# Create a storage account and then create a storage container for the Ubuntu Server 16.04 LTS image.
# Create a new storage account
$StorageAccount = New-AzureRMStorageAccount `
  -Location $location `
  -ResourceGroupName $ResourceGroupName `
  -Type $SkuName `
  -Name $StorageAccountName

Set-AzureRmCurrentStorageAccount `
  -StorageAccountName $storageAccountName `
  -ResourceGroupName $resourceGroupName

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "linuxpublicdns$(Get-Random)"

#Create a network security group and a network security group rule
# Create an inbound network security group rule for port 22
$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig `
-Name $nsgRuleSSHName -Protocol Tcp `
-Direction Inbound -Priority 1000 -SourceAddressPrefix * `
-SourcePortRange * -DestinationAddressPrefix * `
-DestinationPortRange 22 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup `
-ResourceGroupName $ResourceGroupName `
-Location $location `
-Name $nsgName -SecurityRules $nsgRuleSSH

# Create a virtual network card and associate it with public IP address and NSG
$nic = New-AzureRmNetworkInterface `
  -Name myNic `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -SubnetId $Vnet.Subnets[0].Id `
  -PublicIpAddressId $pip.Id `
  -NetworkSecurityGroupId $nsg.Id
  Write-Host "----- Created NIC -----" -ForegroundColor Green

# Define a credential object.
$UserName='demouser'
$VMPassword = 'Password123!'
$securePassword = ConvertTo-SecureString $VMPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $securePassword)

# Create the virtual machine configuration object
$VmName = "LinuxVirtualMachine"
$VmSize = "Standard_D1"
$VirtualMachine = New-AzureRmVMConfig `
  -VMName $VmName `
  -VMSize $VmSize

$VirtualMachine = Set-AzureRmVMOperatingSystem `
  -VM $VirtualMachine `
  -Linux `
  -ComputerName "MainComputer" `
  -Credential $cred

$VirtualMachine = Set-AzureRmVMSourceImage `
  -VM $VirtualMachine `
  -PublisherName "Canonical" `
  -Offer "UbuntuServer" `
  -Skus "16.04-LTS" `
  -Version "latest"

$osDiskName = "OsDisk"
$osDiskUri = '{0}vhds/{1}-{2}.vhd' -f `
  $StorageAccount.PrimaryEndpoints.Blob.ToString(),`
  $vmName.ToLower(), `
  $osDiskName

# Sets the operating system disk properties on a virtual machine.
$VirtualMachine = Set-AzureRmVMOSDisk `
  -VM $VirtualMachine `
  -Name $osDiskName `
  -VhdUri $OsDiskUri `
  -CreateOption FromImage | `
  Add-AzureRmVMNetworkInterface -Id $nic.Id

# Create the virtual machine.
New-AzureRmVM `
  -ResourceGroupName $ResourceGroupName `
 -Location $location `
  -VM $VirtualMachine

Write-Host "----- Launched Linux VM Successfully!!-----" -ForegroundColor Green
Write-Host "----- Launched Linux VM Successfully!!-----" -ForegroundColor Green
Write-Host "----- Adding Extenstion Now -----" -ForegroundColor Green
$TheURI = "https://raw.githubusercontent.com/sangaml/adds_win_Linux/master/joinlinux.sh"
$Settings = @{"fileUris" = @($TheURI); "commandToExecute" = "./joinlinux.sh"};
#
Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -Location $location -VMName $VmName `
-Name "customScript" `
-Publisher "Microsoft.Azure.Extensions" -Type "customScript" -TypeHandlerVersion "2.0" `
-Settings $Settings
