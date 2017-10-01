<#
newlab.ps1
script built to deploy my test Exchange lab using AutomatedLab (https://github.com/AutomatedLab/AutomatedLab)
#>

<#
TO DO:
    Add CA
    Install necessary KBs and .net 4.6.2 on EX13/16
    Figure out networking
#>

$labName = 'EXLab'

#create an empty lab template and define where the lab XML files and the VMs will be stored
New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV -Path E:\AutoLab -vmpath D:\VM

#make the network definition
Add-LabVirtualNetworkDefinition -Name $labName -AddressSpace 10.10.2.1/24

#and the domain definition with the domain admin account
Add-LabDomainDefinition -Name **Domain** -AdminUser **UN** -AdminPassword **pw**

Set-LabInstallationCredential -Username **un** -Password **pw**

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:Network' = $labName
    'Add-LabMachineDefinition:ToolsPath'= "$labSources\Tools"
    'Add-LabMachineDefinition:IsDomainJoined'= $true
	'Add-LabMachineDefinition:DnsServer1'= '10.10.2.101'
	'Add-LabMachineDefinition:DomainName'= 'ehloexchange.net'
}

#Build Domain Controler 
$role = Get-LabMachineRoleDefinition -Role RootDC @{ DomainFunctionalLevel = 'Win2008R2'; ForestFunctionalLevel = 'Win2008R2' }
#The PostInstallationActivity is just creating some users
$postInstallActivity = Get-LabPostInstallationActivity -ScriptFileName PrepareRootDomain.ps1 -DependencyFolder $labSources\PostInstallationActivities\PrepareRootDomain
Add-LabMachineDefinition -Name DC01 -Memory 1024MB -IpAddress 10.10.2.101 -DomainName ehloexchange.net -Roles $role -PostInstallationActivity $postInstallActivity -OperatingSystem 'Windows Server 2016 SERVERSTANDARD'

#Exchange 2010 Server
Add-LabDiskDefinition -Name 10-1 -DiskSizeInGb 20
Add-LabDiskDefinition -Name 10-2 -DiskSizeInGb 20
Add-LabMachineDefinition -Name EX10 -Memory 4GB -Processors 2 -IpAddress 10.10.2.102 -DiskName 10-1,10-2 -OperatingSystem 'Windows Server 2008 R2 SERVERSTANDARD'

#Exchange 2013 Server
Add-LabDiskDefinition -Name 13-1 -DiskSizeInGb 20
Add-LabDiskDefinition -Name 13-2 -DiskSizeInGb 20
Add-LabMachineDefinition -Name EX13 -Memory 8GB -Processors 2 -IpAddress 10.10.2.103 -DiskName 13-1,13-2 -OperatingSystem 'Windows Server 2012 R2 SERVERSTANDARD'

#Exchange 2016-1
Add-LabDiskDefinition -Name 161-1 -DiskSizeInGb 20
Add-LabDiskDefinition -Name 161-2 -DiskSizeInGb 20
Add-LabMachineDefinition -Name EX16-1 -Memory 16GB -Processors 2 -IpAddress 10.10.2.104 -DiskName 161-1,161-2 -OperatingSystem 'Windows Server 2016 SERVERSTANDARD'

#Exchange 2016-2
Add-LabDiskDefinition -Name 162-1 -DiskSizeInGb 20
Add-LabDiskDefinition -Name 162-2 -DiskSizeInGb 20
Add-LabMachineDefinition -Name EX16-2 -Memory 16GB -Processors 2 -IpAddress 10.10.2.105 -DiskName 162-1,162-2 -OperatingSystem 'Windows Server 2016 SERVERSTANDARD'

Install-Lab -NetworkSwitches -BaseImages -VMs

Install-Lab -Domains

Install-Lab -PostInstallations

#Install Exchange PreReqs
#2010
#Add Windows Features
Install-LabWindowsFeature -ComputerName "EX10" -FeatureName NET-Framework,RSAT-ADDS,Web-Server,Web-Basic-Auth,Web-Windows-Auth,Web-Metabase,Web-Net-Ext,Web-Lgcy-Mgmt-Console,WAS-Process-Model,RSAT-Web-Server,Web-ISAPI-Ext,Web-Digest-Auth,Web-Dyn-Compression,NET-HTTP-Activation,Web-Asp-Net,Web-Client-Auth,Web-Dir-Browsing,Web-Http-Errors,Web-Http-Logging,Web-Http-Redirect,Web-Http-Tracing,Web-ISAPI-Filter,Web-Request-Monitor,Web-Static-Content,Web-WMI,RPC-Over-HTTP-Proxy
#Install patch
Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\NDP40-KB2532942-x64.exe -CommandLine '/q'-ComputerName 'EX10'
#2013
#Add Windows Features
Install-LabWindowsFeature -ComputerName "EX13" -FeatureName AS-HTTP-Activation, Desktop-Experience, NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS
#Install runtime
Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\UcmaRuntimeSetup.exe -CommandLine '-q' -ComputerName 'EX13'
#2016
#Install runtime/.net4.5
$16packs = @()
$16packs += Get-LabSoftwarePackage -Path $labSources\SoftwarePackages\UcmaRuntimeSetup.exe -CommandLine '-q'
$16packs += Get-LabSoftwarePackage -Path $labSources\SoftwarePackages\NDP452-KB2901907-x86-x64-ALLOS-ENU.exe -CommandLine '/q'
Install-LabSoftwarePackages -Machine (get-labmachine | where{$_.Name -like "EX16-*"}) -SoftwarePackage $16packs
#Add Windows Features
Install-LabWindowsFeature -ComputerName 'EX16-1', 'EX16-2' -FeatureName NET-Framework-45-Features, RPC-over-HTTP-proxy, RSAT-Clustering, RSAT-Clustering-CmdInterface, RSAT-Clustering-Mgmt, RSAT-Clustering-PowerShell, Web-Mgmt-Console, WAS-Process-Model, Web-Asp-Net45, Web-Basic-Auth, Web-Client-Auth, Web-Digest-Auth, Web-Dir-Browsing, Web-Dyn-Compression, Web-Http-Errors, Web-Http-Logging, Web-Http-Redirect, Web-Http-Tracing, Web-ISAPI-Ext, Web-ISAPI-Filter, Web-Lgcy-Mgmt-Console, Web-Metabase, Web-Mgmt-Console, Web-Mgmt-Service, Web-Net-Ext45, Web-Request-Monitor, Web-Server, Web-Stat-Compression, Web-Static-Content, Web-Windows-Auth, Web-WMI, Windows-Identity-Foundation, RSAT-ADDS

#Copy Install Files needed for Exchange
Copy-LabFileItem -Path 'E:\LabSources\SoftwarePackages\Exchange2013-x64-cu17.exe' -ComputerName 'EX13' -DestinationFolder C:\Installs
Copy-LabFileItem -Path 'E:\LabSources\ISOs\ExchangeServer2016-x64-cu6.iso' -ComputerName 'EX16-1', 'EX16-2' -DestinationFolder C:\Installs
Copy-LabFileItem -Path 'E:\LabSources\SoftwarePackages\Exchange2010-KB4018588-x64-en.msp' -ComputerName 'EX10' -DestinationFolder C:\Installs
Copy-LabFileItem -Path 'E:\LabSources\SoftwarePackages\Exchange2010-SP3-x64.exe' -ComputerName 'EX10' -DestinationFolder C:\Installs
Copy-LabFileItem -Path 'E:\LabSources\SoftwarePackages\FilterPack64bit.exe' -ComputerName 'EX10', 'EX13' -DestinationFolder C:\Installs
Copy-LabFileItem -Path 'E:\LabSources\SoftwarePackages\filterpack2010sp1-kb2460041-x64-fullfile-en-us.exe' -ComputerName 'EX10', 'EX13' -DestinationFolder C:\Installs

#Show Summary
Show-LabDeploymentSummary -Detailed
