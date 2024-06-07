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