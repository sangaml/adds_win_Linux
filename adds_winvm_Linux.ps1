# Change the following values to match your deployment.
$AaddsAdminUserUpn = "sangaml@sangamlonkar14.cf"
$AzureSubscriptionId = "8c879d4b-1e31-438b-8f74-41093d5c4b83"
$ManagedDomainName = "sangamlonkar14.cf"
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
