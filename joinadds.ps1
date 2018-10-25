Get-AzureRmVM -ResourceGroupName 'ADDRG' | Where-Object {$_.Name -like '*ADDVM1*'} |
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
       } catch {
           Write-Warning $_
       }
   }
   end { }
}
Add-JDAzureRMVMToDomain
