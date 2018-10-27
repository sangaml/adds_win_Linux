########################################################################
#    Creating  VMs and adding to Azure Domain                          #
#          using Power shell scripting                                 #
#          Created by Sangam                                           #
########################################################################

$date = Get-Date -Format g
Write-Host "Starting Deploying........  on $date" -ForegroundColor Green
write-host "
#################################################
#           Launching Win VM                    #
################################################# " -ForegroundColor Green

########### VARIBLES USED ##########################
$ResourceGroupName = "ADDRG"
$location = "westus"
$DomainName = "sangamlonkar14.cf"

# Define a credential object to store the username and password for Azure Domain
$secpasswd = ConvertTo-SecureString 'Lkjhg5fdsa@' -AsPlainText -Force
$Credentials = New-Object System.Management.Automation.PSCredential("pradnesh@sangamlonkar14.cf",$secpasswd)

# Define a credential object to store the username and password for the virtual machines
$UserName='demouser'
$Password='Password@123'| ConvertTo-SecureString -Force -AsPlainText
$Credential=New-Object PSCredential($UserName,$Password)

 
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


function Add-JDAzureRMVMToDomain {
 
           $Settings = @{
            Name = $DomainName
            User = $Credentials.UserName
            Restart = "true"
            Options = 3
                        }
           $ProtectedSettings =  @{
                Password = $Credentials.GetNetworkCredential().Password
                                  }
           
        
           $JoinDomainHt = @{
                ResourceGroupName = $RG
                ExtensionType = 'JsonADDomainExtension'
                Name = 'joindomain'
                Publisher = 'Microsoft.Compute'
                TypeHandlerVersion = '1.0'
                Settings = $Settings
                VMName = $winVmName
                ProtectedSettings = $ProtectedSettings
                Location = $location
                            }
                        Set-AzureRMVMExtension @JoinDomainHt
       
       }
 write-host "Getting Domainname is: $DomainName" -ForegroundColor Green
 Start-Sleep 10
 write-host "Joining $winVmName to $DomainName .................. " -ForegroundColor Green
  
 # Calling function to connect to domain  
 Add-JDAzureRMVMToDomain
 Start-Sleep 360
 
 Write-Host "Please wait.... your Machine:$winVmName is configuring for login"
 
 #  Providing access to user for remote login
 Set-AzureRmVMCustomScriptExtension -ResourceGroupName $ResourceGroupName `
               -VMName $winVmName -Name "myCustomScript" `
               -FileUri "https://raw.githubusercontent.com/sangaml/adds_win_Linux/master/userpermission.ps1" `
               -Run "userpermission.ps1" `
               -Location $location

Write-Host " $winVmName is now connected to $DomainName " -ForegroundColor Green
   
Write-Host "----- Added VM to Azure Active directory domain Service -----" -ForegroundColor Green
#################################################
#           Launching Linux VM                  #
################################################# " -ForegroundColor Green

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

  $linuxpip = New-AzureRmPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -AllocationMethod Static `
  -IdleTimeoutInMinutes 4 `
  -Name "Linuxpublicdns$(Get-Random)"

  $nsgRulessh = New-AzureRmNetworkSecurityRuleConfig `
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
$linuxnsg = New-AzureRmNetworkSecurityGroup `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -Name $nsgName `
  -SecurityRules $nsgRulessh

  $linuxnic = New-AzureRmNetworkInterface `
  -Name "LinuxmyNic" `
  -ResourceGroupName $ResourceGroupName `
  -Location $location `
  -SubnetId $Vnet.Subnets[0].Id `
  -PublicIpAddressId $linuxpip.Id `
  -NetworkSecurityGroupId $linuxnsg.Id

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
  -ComputerName "linuxvm" `
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
  Add-AzureRmVMNetworkInterface -Id $linuxnic.Id

# Create the virtual machine.
New-AzureRmVM `
  -ResourceGroupName $ResourceGroupName `
 -Location $location `
  -VM $VirtualMachine

Write-Host "----- Launched Linux VM Successfully!!-----" -ForegroundColor Green
Write-Host "----- Adding Extenstion Now -----" -ForegroundColor Green
$TheURI = "https://raw.githubusercontent.com/sangaml/adds_win_Linux/master/joinlinuxtoadds.sh"
$Settings = @{"fileUris" = @($TheURI); "commandToExecute" = "./joinlinuxtoadds.sh"};
#
Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -Location $location -VMName $VmName `
-Name "customScript" `
-Publisher "Microsoft.Azure.Extensions" -Type "customScript" -TypeHandlerVersion "2.0" `
-Settings $Settings

Write-Host "----- Launched Linux VM Successfully!!-----" -ForegroundColor Green

Write-Host "----- Adding VM into Azure AD DS -----" -ForegroundColor Green

$TheURI = "https://raw.githubusercontent.com/sangaml/adds_win_Linux/master/joinlinuxtoadds.sh"
$Settings = @{"fileUris" = @($TheURI); "commandToExecute" = "./joinlinuxtoadds.sh"};
#
Set-AzureRmVMExtension -ResourceGroupName $ResourceGroupName -Location $location -VMName $VmName `
-Name "customScript" `
-Publisher "Microsoft.Azure.Extensions" -Type "customScript" -TypeHandlerVersion "2.0" `
-Settings $Settings

Write-Host "----- Added VM into Azure AD DS -----" -ForegroundColor Green
Write-Host "----- Login With IP -----" -ForegroundColor Green
