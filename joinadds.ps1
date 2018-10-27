$RG = ADDRG
Get-AzureRmVM -ResourceGroupName $RG | Where-Object {$_.Name -like 'winVirtualMachine'} |
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
