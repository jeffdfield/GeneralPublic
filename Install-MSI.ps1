


#===========================================================================Get-MSIProps==========================================================================================

Function Global:Get-MSIProps {
<#  
.SYNOPSIS  
    Gets the properties of an MSI and all switches

.DESCRIPTION
    Gets the properties of an MSI and all switches

.EXAMPLE
    Get-MSIProps 

.NOTES  
 Version : 1.0.0
 Author: Jeffery Field
 LastUpdate: 3/26/24 1:38 PM
 Source:
 Change Log:
#>

    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string[]]$MSIPath = $msipath
    )

#Get MSI files in the scripts path
$MSIs = Get-ChildItem -Filter *.msi
If($MSIs.count -eq '1' -and $msipath -eq $null){
$msipath = "$($msis.FullName)"
$MsiNoSpace = $MSIs.Name.replace(' ','')
$MSILogFileName = $MsiNoSpace.replace('msi','txt')
$MSILogPath = "C:\IT\$MSILogFileName"
}

#If there is more than 1 msi in the path and the MSI path wasn't specified throw an error
If($MSIs.count -gt '1' -and $msipath -eq $null){throw "More than 1 msi in path and the path wasn't specified"}

$pathToMSI = $msipath

$msiOpenDatabaseModeReadOnly = 0
$msiOpenDatabaseModeTransact = 1

$windowsInstaller = New-Object -ComObject windowsInstaller.Installer

$database = $windowsInstaller.GetType().InvokeMember("OpenDatabase", "InvokeMethod", $null, $windowsInstaller, @($pathToMSI, $msiOpenDatabaseModeReadOnly))

$query = "SELECT Property, Value FROM Property"
$propView = $database.GetType().InvokeMember("OpenView", "InvokeMethod", $null, $database, ($query))
$propView.GetType().InvokeMember("Execute", "InvokeMethod", $null, $propView, $null) | Out-Null
$propRecord = $propView.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $propView, $null)

$MSIProps = @()
$Obj=New-Object PSObject

while  ($propRecord -ne $null)
{
	$col1 = $propRecord.GetType().InvokeMember("StringData", "GetProperty", $null, $propRecord, 1)
	$col2 = $propRecord.GetType().InvokeMember("StringData", "GetProperty", $null, $propRecord, 2)
 
	#write-host $col1 - $col2
    $itemdetails = [PScustomObject]@{
    MSIProperty = $col1
    Value = $col2
    }
    $Global:MSIProps += $itemdetails

	#fetch the next record
	$propRecord = $propView.GetType().InvokeMember("Fetch", "InvokeMethod", $null, $propView, $null)	
}

$propView.GetType().InvokeMember("Close", "InvokeMethod", $null, $propView, $null) | Out-Null -ErrorAction Ignore       
$propView = $null 
$propRecord = $null
$database = $null

}

Get-MSIProps

If($Global:MSIProps -ne $null){
    $MSIObj=New-Object PSObject
    foreach($Prop in $Global:MSIProps){

    $MSIObj | Add-Member -Name "$($prop.MSIProperty)" -MemberType NoteProperty  -Value "$($prop.Value)"
    $AllMsiProps += $MSIobj
    Write-Host "Adding $($prop.MSIProperty)" -MemberType NoteProperty  -Value "$($prop.Value)"
}

}else{throw "Could not get MSI properties"}

$MSIObj

#===========================================================================Install MSI==========================================================================================

Function Global:Install-MSI{
<#  
.SYNOPSIS  
    Installs MSI

.DESCRIPTION
    Installs an MSI file

.EXAMPLE
    Install-MSI

.NOTES  
 Version : 1.0.0
 Author: Jeffery Field
 CompanyName: Under Armour, Inc.
 LastUpdate: 3/26/24 1:38 PM
 Source: Documents - Teammate Experience\Intune\Scripts
 Change Log:
#>

    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string[]]$MSIPath = $msipath,
        [string[]]$MSILogPath = $msilogpath
    )

$MSIExecExitCodes = @()

$MSIExecExitData = "0:ERROR_SUCCESS:Action completed successfully.",
"1602:ERROR_INSTALL_USEREXIT:User cancel installation.",
"1603:ERROR_INSTALL_FAILURE:Fatal error during installation.",
"1608:ERROR_UNKNOWN_PROPERTY:Unknown property.",
"1609:ERROR_INVALID_HANDLE_STATE:Handle is in an invalid state.",
"1614:ERROR_PRODUCT_UNINSTALLED:Product is uninstalled.",
"1618:ERROR_INSTALL_ALREADY_RUNNING:Another installation is already in progress. Complete that installation before proceeding with this install.",
"1619:ERROR_INSTALL_PACKAGE_OPEN_FAILED:This installation package could not be opened. ",
"1620:ERROR_INSTALL_PACKAGE_INVALID:This installation package could not be opened. ",
"1624:ERROR_INSTALL_TRANSFORM_FAILURE:Error applying transforms. Verify that the specified transform paths are valid.",
"1635:ERROR_PATCH_PACKAGE_OPEN_FAILED:This patch package could not be opened.",
"1636:ERROR_PATCH_PACKAGE_INVALID:This patch package could not be opened.",
"1638:ERROR_PRODUCT_VERSION:Another version of this product is already installed. Installation of this version cannot continue.",
"1639:ERROR_INVALID_COMMAND_LINE:Invalid command line argument.",
"1640:ERROR_INSTALL_REMOTE_DISALLOWED:Installation from a Terminal Server client session not permitted for current user.",
"1641:ERROR_SUCCESS_REBOOT_INITIATED:The installer has started a reboot.",
"1644:ERROR_INSTALL_TRANSFORM_REJECTED:One or more customizations are not permitted by system policy.",
"3010:ERROR_SUCCESS_REBOOT_REQUIRED:A reboot is required to complete the install."


Foreach($Item in $MSIExecExitData){
$Split = $null
$Split = $Item.split(":")

$ErrorCode = $Split[0]
$ErrorName = $Split[1]
$ErrorDesc = $Split[2]

$ItemDetails = [PSCustomObject]@{
ErrorCode = $ErrorCode
ErrorName = $ErrorName
ErrorDesc = $ErrorDesc
}
$MSIExecExitCodes += $ItemDetails
}

Write-output "The MSI path is $msipath and the log file name is $MSILogPath"

$MSIArguments = "/I ""$msipath"" /QN /norestart /L*V $MSILogPath"



    $msiargs = @(
        "/i"
        "`"$msipath`""
        #'INSTALLDIR="C:\PRGS\PTC\Creo Elements\Direct 3D Access 20.1\"'
        #"MELS=LOCALHOST"
        "/qn"
        "/L*V $MSILogPath"
        "/Norestart"
    )

$Result = (start-process msiexec.exe -ArgumentList $msiargs -wait -PassThru)

$Exit = $MSIExecExitCodes | where-object ErrorCode -eq $Result.ExitCode

Write-Output "The exit code was $($Exit.ErrorCode). The statuse was $($Exit.ErrorName). The description was $($exit.errordesc)."

If($($Exit.ErrorCode) -eq 0 -or $($Exit.ErrorCode) -eq 1707){
$global:status = "Success"
$global:ExitCode = "0"
}

If($($Exit.ErrorCode) -eq 3010 -or $($Exit.ErrorCode) -eq 1641){
$global:status = "Reboot"
$global:ExitCode = "3010"
}
$global:status = "Error"
$global:ExitCode = "9999"
}


Write-Host "Starting Install-MSI function"
Install-MSI

Write-Host "Status is $status"
Exit $exitcode

