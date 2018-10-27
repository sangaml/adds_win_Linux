#################################################
#           Launching Win VM                    #
#################################################
$ResourceGroupName = "ADDRG"
$location = "westus"

$Vnet=Get-AzureRmVirtualNetwork `
  -Name "ADDNet" -ResourceGroupName "ADDRG"

  $winpip = New-AzureRmPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "winpublicdns$(Get-Random)"

  $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
  -Name winNetworkSecurityGroupRuleRDP `
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
  -Name winNetworkSecurityGroup `
  -SecurityRules $nsgRuleRDP

  $winnic = New-AzureRmNetworkInterface `
  -Name "winmyNic" `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -SubnetId $Vnet.Subnets[0].Id `
  -PublicIpAddressId $winpip.Id `
  -NetworkSecurityGroupId $winnsg.Id
# Define a credential object to store the username and password for the virtual machine
$UserName='demouser'
$Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($UserName,$Password)

# Create the virtual machine configuration object
$winVmName = "WinVirtualMachinetest"
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

New-AzureRmVM `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -VM $winVirtualMachine

Write-Host "----- Launched Windows VM Successfully!!-----" -ForegroundColor Green
Write-Host "----- Now adding VM to Azure Active directory domain Service -----" -ForegroundColor Green
  $RG='ADDRG'

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
Write-Host "----- Added VM to Azure Active directory domain Service -----" -ForegroundColor Green
#################################################
#           Launching Linux VM                  #
#################################################
Write-Host "----- Launching Linux VM  -----" -ForegroundColor Green
$random = (New-Guid).ToString().Substring(0,4)

$StorageAccountName = "linuxstorage$random"
$SkuName = "Standard_LRS"

# Create variables to store the network security group and rules names.
$nsgName = "sshNetworkSecurityGroup"
$nsgRuleSSHName = "NetworkSecurityGroupRuleSSH"

$StorageAccount = New-AzureRMStorageAccount `
  -Location $location `
  -ResourceGroupName $ResourceGroupName `
  -Type $SkuName `
  -Name $StorageAccountName

Set-AzureRmCurrentStorageAccount `
  -StorageAccountName $storageAccountName `
  -ResourceGroupName $resourceGroupName


$Vnet=Get-AzureRmVirtualNetwork `
  -Name "ADDNet" -ResourceGroupName "$ResourceGroupName"

  $winpip = New-AzureRmPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "Linuxpublicdns$(Get-Random)"

  $nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig `
  -Name "$nsgRuleSSHName" `
  -Protocol Tcp `
  -Direction Inbound `
  -Priority 1000 `
  -SourceAddressPrefix * `
  -SourcePortRange * `
  -DestinationAddressPrefix * `
  -DestinationPortRange 22 `
  -Access Allow

# Create a network security group
$winnsg = New-AzureRmNetworkSecurityGroup `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -Name $nsgName `
  -SecurityRules $nsgRuleRDP

  $winnic = New-AzureRmNetworkInterface `
  -Name "LinuxmyNic" `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -SubnetId $Vnet.Subnets[0].Id `
  -PublicIpAddressId $winpip.Id `
  -NetworkSecurityGroupId $winnsg.Id

  $UserName='demouser'
$VMPassword = 'Password123!'
$securePassword = ConvertTo-SecureString $VMPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ($UserName, $securePassword)

# Create the virtual machine configuration object
$VmName = "LinuxVirtualMachinetest"
$VmSize = "Standard_D1"
$VirtualMachine = New-AzureRmVMConfig `
  -VMName $VmName `
  -VMSize $VmSize

$VirtualMachine = Set-AzureRmVMOperatingSystem `
  -VM $VirtualMachine `
  -Linux `
  -ComputerName "LinuxMainComputer" `
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
  Add-AzureRmVMNetworkInterface -Id $winnic.Id

# Create the virtual machine.
New-AzureRmVM `
  -ResourceGroupName $ResourceGroupName `
 -Location $location `
  -VM $VirtualMachine

Write-Host "----- Launched Linux VM Successfully!!-----" -ForegroundColor Green
Write-Host "----- Joining VM TO AD DS-----" -ForegroundColor Green
$TheURI = "https://raw.githubusercontent.com/sangaml/adds_win_Linux/master/joinlinux.sh"
$Settings = @{"fileUris" = @($TheURI); "commandToExecute" = "./joinlinux.sh"};
#
Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -Location $location -VMName $VmName `
-Name "customScript" `
-Publisher "Microsoft.Azure.Extensions" -Type "customScript" -TypeHandlerVersion "2.0" `
-Settings $Settings
Write-Host "----- Joined VM TO AD DS-----" -ForegroundColor Green
