# Change the following values to match your deployment.
$AaddsAdminUserUpn = "sangaml@projectride.ml"
$AzureSubscriptionId = "8c879d4b-1e31-438b-8f74-41093d5c4b83"
$ManagedDomainName = "projectride.ml"
$ResourceGroupName = "AaddsRg1"
$VnetName = "DomainServicesVNet_WUS"
$location = "westus"

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

# Create the resource group.
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

# Enable Azure AD Domain Services for the directory.
New-AzureRmResource -ResourceId "/subscriptions/$AzureSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.AAD/DomainServices/$ManagedDomainName" `
  -Location $location `
  -Properties @{"DomainName"=$ManagedDomainName; `
    "SubnetId"="/subscriptions/$AzureSubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Network/virtualNetworks/$VnetName/subnets/DomainServices"} `
  -ApiVersion 2017-06-01 -Force -Verbose

<############3
# Create variables to store the storage account name and the storage account SKU information
$random1 = (New-Guid).ToString().Substring(0,8)
$StorageAccountName = "mystorageaccount$random1"
$SkuName = "Standard_LRS"

# Create a new storage account
$StorageAccount = New-AzureRMStorageAccount `
  -Location $location `
  -ResourceGroupName $ResourceGroupName `
  -Type $SkuName `
  -Name $StorageAccountName

Set-AzureRmCurrentStorageAccount `
  -StorageAccountName $storageAccountName `
  -ResourceGroupName $resourceGroupName

# Create a storage container to store the virtual machine image
$containerName = 'osdisks'
$container = New-AzureStorageContainer `
  -Name $containerName `
  -Permission Blob

  # Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress `
-ResourceGroupName $ResourceGroupName `
-Location $location `
-AllocationMethod Static `
-IdleTimeoutInMinutes 4 `
-Name "mypublicdns$(Get-Random)"

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
  $nsg = New-AzureRmNetworkSecurityGroup `
    -Name myNetworkSecurityGroup `
    -ResourceGroupName $ResourceGroupName `
    -Location $location `
    -SecurityRules $nsgRuleRDP
# Create a virtual network card and associate it with public IP address and NSG    
    $nic = New-AzureRmNetworkInterface `
    -Name myNic `
    -ResourceGroupName $ResourceGroupName `
    -Location $location `
    -SubnetId $Vnet.Subnets[0].Id `
    -PublicIpAddressId $pip.Id `
    -NetworkSecurityGroupId $nsg.Id

    # Define a credential object to store the username and password for the virtual machine
$UserName='demouser'
$Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($UserName,$Password)

# Create the virtual machine configuration object
$VmName = "VirtualMachinelatest"
$VmSize = "Standard_A1"
$VirtualMachine = New-AzureRmVMConfig `
  -VMName $VmName `
  -VMSize $VmSize

$VirtualMachine = Set-AzureRmVMOperatingSystem `
  -VM $VirtualMachine `
  -Windows `
  -ComputerName "MainComputer" `
  -Credential $Credential

$VirtualMachine = Set-AzureRmVMSourceImage `
  -VM $VirtualMachine `
  -PublisherName "MicrosoftWindowsServer" `
  -Offer "WindowsServer" `
  -Skus "2016-Datacenter" `
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

  #insatll Custom ScriptExtension

<#Set-AzureRmVMCustomScriptExtension -ResourceGroupName myResourceGroup `
    -VMName $VmName `
    -Location $location `
    -FileUri "D:\dev\scripts" `
    -Run 'joinad.ps1' `
    -Name ADScriptExtension
    #>     
