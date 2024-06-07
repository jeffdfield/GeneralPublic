<#
Created by: Jeffery Field (jfield)
Purpose: Installs New Teams Clients



		:Change Log:
	2/21/24 - initial write
    
#>


Function Set-IntuneSuccess {
<#  
.SYNOPSIS  
    Creates Registry Key for Intune success criteria

.DESCRIPTION
    Creates Registry Key for Intune success criteria

.EXAMPLE
    Set-IntuneSuccess -KeyValue "$($MSIObj.ProductVersion)" -Keyname "FireFox_Version"
    Runs with default parameters
    Set-IntuneSuccess

.NOTES  
 Version: 1.0.0
 Author: Jeffery Field
 Description: Sets Intune Success Criteria
 Guid: 99b832ff-f003-4394-baca-7043b1f13ab2
 Tags: Intune,LOB,App
 LastUpdate: 3/26/24 1:38 PM
 Source:
#>


    [CmdletBinding()] #<<-- This turns a regular function into an advanced function
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory,HelpMessage='Enter the key name!')]$KeyName,
        [string[]]$KeyValue = "1.0.0"
    )

#Defaults
#Get Date Time
Write-output "Setting success registry key"

#Test path
$RegKeyName = "Intune"
$FullRegKeyName = "HKLM:\\SOFTWARE\" + $regkeyname

$TP = Test-Path -Path "$FullRegKeyName"

If($TP -ne $true){
#Create reg path
Write-output "Creating reg path"
New-Item -Path $FullRegKeyName -type Directory -Force -ErrorAction SilentlyContinue
}else{
Write-output "Full path already there"
}

# Write values
new-itemproperty $FullRegKeyName -Name "$KeyName" -Value $KeyValue -Type STRING -Force -ErrorAction SilentlyContinue | Out-Null
Write-output "Completed Function"

}




#Switch to the invocaton pat(where the script is on disk) so the cache of intune or WS1
$scriptpath = $MyInvocation.MyCommand.Path
$scriptname = $MyInvocation.MyCommand.name
$dir = Split-Path $scriptpath
Set-Location $dir


Start-Transcript -Path "c:\IT\Teams-Install.txt"
Write-Host "Executing $scriptname"


$BS = Start-Process -FilePath .\teamsbootstrapper.exe -ArgumentList "-p -o `"$dir\MSTeams-x64.msix`"" -PassThru -Wait -NoNewWindow
Write-Host "Install Exit code is $($bs.ExitCode)"

$AppName = "MSTeams"

$Appx = Get-AppxPackage -AllUsers | Where-Object {$PSItem. Name -eq $AppName}
$ProvApp = Get-ProvisionedAppPackage -Online | Where-Object {$PSItem. DisplayName -eq $AppName}

if($appx -ne $null -and $ProvApp -ne $null){

[System.version]$ProvappVer = $ProvApp.version
[System.version]$appxVer = $Appx.version

[System.version]$CurrentVer = "23004.0001.0001.0001"

If($ProvappVer -gt $CurrentVer -and $Appxver -gt $CurrentVer ){
Write-Host "Installed version is new enough"
$installed = $true
}else{
Write-Host "Installed version is NOT new enough"
$installed = $false
}


if($installed = $true){
Write-Host "Teams install successfully"
reg add "HKCU\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" /v State /t REG_DWORD /d 2 /f


Set-IntuneSuccess -KeyValue "NewTeams" -Keyname "MicrosoftTeams"

}else{

}


}






Stop-Transcript

