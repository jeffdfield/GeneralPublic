
<#
.SYNOPSIS
  
.DESCRIPTION
 
.PARAMETER <Parameter_Name>
    
.INPUTS
  None
.OUTPUTS
  Logs to "C:\Temp\AP-Provision-Device-Phase-$((Get-Date).TimeofDay)-$($ENV:COMPUTERNAME).log"
.NOTES
    Version:        1.0.0.0
    Author:         Author Name
    Creation Date:  00/00/0000
    Purpose/Change: Changed....

.EXAMPLE

#>


#----------------------------------------------------------------------------[ Begin Declarations ]----------------------------------------------------------

$Logpath = "C:\Temp\AP-Provision-Device-Phase-$((Get-Date).ToString('yyyyMMdd-HHmmss'))-$($ENV:COMPUTERNAME).log"
$ST = Start-Transcript -Path "$Logpath" -Append -force

#---------------------------------------------------------------------------[ End Initialisations ]--------------------------------------------------------



#-----------------------------------------------------------------------------[ Begin Functions ]------------------------------------------------------------


Function Install-Nuget{
    #Check for Nuget
    $CheckNuget = Get-PackageProvider
    if  ($CheckNuget.Name -eq "Nuget")
        {Write-Output "[$((Get-Date).TimeofDay)] [Info] Nuget module found"}
    else{
        Write-Output "[$((Get-Date).TimeofDay)] [Info] Installing Nuget module"
        Try{
          Install-PackageProvider Nuget -MinimumVersion 2.8.5.201 -Force -Verbose -Scope AllUsers -ForceBootstrap -ErrorAction Stop
        }Catch{
          Write-Output "[$((Get-Date).TimeofDay)] [ERROR] Failed to install Nuget module"
          Exit 70002
        }
    }




function Install-PowerShell7MSI {
    [CmdletBinding()]
    param (
    [ValidateNotNullOrEmpty()]
    [string[]]$MSIPath
    )



    try {
        Get-MSIProperties -msi "$MSIPath"
        $ProductCode = $ProductMSIProps | where-object MSIProperty -eq "ProductCode" | Select-Object -ExpandProperty Value
        $ProductVersion = $ProductMSIProps | where-object MSIProperty -eq "ProductVersion" | Select-Object -ExpandProperty Value
        $ProductName = $ProductMSIProps | where-object MSIProperty -eq "ProductName" | Select-Object -ExpandProperty Value
    }
    catch {
        Write-Output "[$((Get-Date).TimeofDay)] [ERROR] Getting MSI properties failed"
    }
    

    $MSIExitData = @(
        ("0","ERROR_SUCCESS","Action completed successfully."),
        ("1602","ERROR_INSTALL_USEREXIT","User cancel installation."),
        ("1603","ERROR_INSTALL_FAILURE","Fatal error during installation."),
        ("1608","ERROR_UNKNOWN_PROPERTY","Unknown property."),
        ("1609","ERROR_INVALID_HANDLE_STATE","Handle is in an invalid state."),
        ("1614","ERROR_PRODUCT_UNINSTALLED","Product is uninstalled."),
        ("1618","ERROR_INSTALL_ALREADY_RUNNING","Another installation is already in progress. Complete that installation before proceeding with this install."),
        ("1619","ERROR_INSTALL_PACKAGE_OPEN_FAILED","This installation package could not be opened."),
        ("1620","ERROR_INSTALL_PACKAGE_INVALID","This installation package could not be opened."),
        ("1624","ERROR_INSTALL_TRANSFORM_FAILURE","Error applying transforms. Verify that the specified transform paths are valid."),
        ("1635","ERROR_PATCH_PACKAGE_OPEN_FAILED","This patch package could not be opened."),
        ("1636","ERROR_PATCH_PACKAGE_INVALID","This patch package could not be opened."),
        ("1638","ERROR_PRODUCT_VERSION","Another version of this product is already installed. Installation of this version cannot continue."),
        ("1639","ERROR_INVALID_COMMAND_LINE","Invalid command line argument."),
        ("1640","ERROR_INSTALL_REMOTE_DISALLOWED","Installation from a Terminal Server client session not permitted for current user."),
        ("1641","ERROR_SUCCESS_REBOOT_INITIATED","The installer has started a reboot."),
        ("1644","ERROR_INSTALL_TRANSFORM_REJECTED","One or more customizations are not permitted by system policy."),
        ("3010","ERROR_SUCCESS_REBOOT_REQUIRED","A reboot is required to complete the install.")
    )

    $MSIExecExitCodes = @()
    foreach ($Item in $MSIExitData) {
        $ItemDetails = [PSCustomObject]@{
            ErrorCode = $Item[0]
            ErrorName = $Item[1]
            ErrorDesc = $Item[2]
        }
        $MSIExecExitCodes += $ItemDetails
    }

    try {
        
        $Result = start-process msiexec.exe -ArgumentList "/i $msipath /qn ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1 ENABLE_PSREMOTING=1 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1 ADD_PATH=1 /l*v .\PowerShellMSI.log" -wait -PassThru
        $MSIResult = $MSIExecExitCodes | Where-Object {$_.ErrorCode -eq $($Result.ExitCode)}
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Ran MSI for $ProductName version $productversion. the exit code was $($Result.ExitCode)"
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] MSI exit desc is: $($MSIResult.ErrorDesc)"

        If($($Result.ErrorCode) -eq 0 -or $($Result.ErrorCode) -eq 1707){
            Write-Output "[$((Get-Date).TimeofDay)] [INFO] Ran MSI for $ProductName version $productversion. The install was successful"
                    $MSIResult = $MSIExecExitCodes | Where-Object {$_.ErrorCode -eq $($Result.ExitCode)}
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Ran MSI for $ProductName version $productversion. the exit code was $($Result.ExitCode)"
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] MSI exit desc is: $($MSIResult.ErrorDesc)"
        }

        If($($Result.ErrorCode) -eq 3010 -or $($Result.ErrorCode) -eq 1641){
            Write-Output "[$((Get-Date).TimeofDay)] [INFO] Ran MSI for $ProductName version $productversion. The install was successful but a reboot is required"
            $MSIResult = $MSIExecExitCodes | Where-Object {$_.ErrorCode -eq $($Result.ExitCode)}
            Write-Output "[$((Get-Date).TimeofDay)] [INFO] Ran MSI for $ProductName version $productversion. the exit code was $($Result.ExitCode)"
            Write-Output "[$((Get-Date).TimeofDay)] [INFO] MSI exit desc is: $($MSIResult.ErrorDesc)"
        }

    }catch {
        Write-Output "[$((Get-Date).TimeofDay)] [ERROR] Could not run MSI install. For $ProductName version $productversion"
    }

}






function Install-VcRedistributable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InstallerPath,

        [Parameter(Mandatory=$false)]
        [switch]$Silent
    )

    if (-not (Test-Path $InstallerPath)) {
        Write-output "[$((Get-Date).TimeofDay)] [ERROR] Installer file not found at: $InstallerPath"
        throw "Installer file not found."
        return
    }

    $arguments = "/install" # Default argument for some installers
    if ($Silent) {
        $arguments += " /quiet /norestart" # Common silent installation arguments
    }

    Write-Output "[$((Get-Date).TimeofDay)] [INFO]  Installing Visual C++ Redistributable from $InstallerPath"
    Write-Output "[$((Get-Date).TimeofDay)] [INFO] Silent mode: $Silent"


    try {
        write-Output "[$((Get-Date).TimeofDay)] [INFO] Starting installation process for $InstallerPath with arguments: $arguments"
        $StProcCplus = Start-Process -FilePath $InstallerPath -ArgumentList $arguments -Wait -PassThru
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Installation process completed with exit code: $($StProcCplus.ExitCode)"
    }
    catch {
        write-Output "[$((Get-Date).TimeofDay)] [ERROR] Failed to start installation process for $InstallerPath. Error: $($_.Exception.Message)"
        Throw "Visual C++ Redistributable installation process failed!"
    }
}




#-----------------------------------------------------------------------------[ End Functions ]------------------------------------------------------------------------------------------------------------------------

#---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

#-----------------------------------------------------------------------------[ Begin Code ]-----------------------------------------------------------------------------------------------------------------------------------------



#---------------------------------[ Install Nuget ]---------------------------------
try {
    Write-Output "[$((Get-Date).TimeofDay)] [INFO] Attempting to install Nuget provider."
    Install-Nuget
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Output "[$((Get-Date).TimeofDay)] [ERROR] Installing Nuget provider failed"
}




#---------------------------------[ Install Visual C++ Redistributable ]---------------------------------
try {
    Write-Output "[$((Get-Date).TimeofDay)] [INFO] Installing Visual C++ Redistributable"
    Install-VcRedistributable -InstallerPath ".\vc_redist.x64.exe" -Silent  -ErrorAction Continue
    Write-Output "[$((Get-Date).TimeofDay)] [INFO] Installed Visual C++ Redistributable"
}
catch {
    <#Do this if a terminating exception happens#>
    write-Output "[$((Get-Date).TimeofDay)] [ERROR] Installing Visual C++ Redistributable Failed"
}



#---------------------------------[ Install PowerShell 7 ]---------------------------------
If ($Arch -eq "ARM64") {
        <# Action to perform if the condition is true #>
        try {
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Attempting to install PowerShell 7 ARM64"
        Install-PowerShell7MSI -MSIPath .\AP-Provision\PowerShell-7.5.2-win-arm64.msi
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] PowerShell 7 install ran."
    }catch {
        Write-Output "[$((Get-Date).TimeofDay)] [ERROR] Installing PowerShell 7 Failed"
    }
}else{
    try {
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Attempting to install PowerShell 7 x64"
        Install-PowerShell7MSI -MSIPath .\AP-Provision\PowerShell-7.5.2-win-x64.msi
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] PowerShell 7 install ran."
    }catch {
        Write-Output "[$((Get-Date).TimeofDay)] [ERROR] Installing PowerShell 7 Failed"
    }
}



#---------------------------------[ Install Winget Apps ]---------------------------------

try {
    #Set architecture variables
    $Arch = $env:PROCESSOR_ARCHITECTURE
    If($Arch -eq "ARM64"){
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Running on 64-bit ARM architecture"
            $Ids = @(
            #9WZDNCRD29V9 is Microsoft CoPilot 365
            '9WZDNCRD29V9',
            'Microsoft.VCRedist.2015+.arm64',
            'Microsoft.EdgeWebView2Runtime',
            'Microsoft.CompanyPortal'
            )
    }else{
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Architecture is X64"
            $Ids = @(
            #9WZDNCRD29V9 is Microsoft CoPilot 365
            '9WZDNCRD29V9',
            'Microsoft.VCRedist.2015+.x64',
            'Microsoft.EdgeWebView2Runtime',
            'Microsoft.CompanyPortal'
            )

    }

    write-Output "[$((Get-Date).TimeofDay)] [INFO] Winget Steps - Setting PS repo to trusted."
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -SourceLocation "https://www.powershellgallery.com/api/v2" -ErrorAction Continue

    write-Output "[$((Get-Date).TimeofDay)] [INFO] Winget Steps - Setting Execution Policy to Bypass for Process."
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Force -Scope Process -ErrorAction Continue

    write-Output "[$((Get-Date).TimeofDay)] [INFO] Winget Steps - Installing Module."
    Install-Module -Name Microsoft.WinGet.Client -Force -Scope AllUsers -Repository PSGallery
    write-Output "[$((Get-Date).TimeofDay)] [INFO] Winget Steps - Installed Module. Now to apps."
    

    #I did not need to repair winget. A lot of blogs say to do this. But I think it is fixed in latest Windows 11 builds.
    #write-Output "[$((Get-Date).TimeofDay)] [INFO] Repairing Winget package manager."  
    #Repair-WinGetPackageManager -Force -Latest -ErrorAction Continue
    #write-Output "[$((Get-Date).TimeofDay)] [INFO] Winget package manager repair completed."
        
        
    foreach ($id in $Ids) {
        #From this blog: https://powershellisfun.com/2025/05/16/deploy-and-automatically-update-winget-apps-in-intune-using-powershell-without-remediation-or-3rd-party-tools/?noamp=available
        #PowerShell 7 is required. 5.1 Gave an error: This cmdlet is not supported in Windows PowerShell. This is a known issue with 5.1 and running in system context.

        $PS7Proc = Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" -argumentList "-MTA -Command `"Install-WinGetPackage -Id $Id -Mode Silent -Scope SystemOrUnknown -ErrorAction Continue`"" -Wait -NoNewWindow -PassThru
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Installed Winget package with ID: $Id. Exit code: $($PS7Proc.ExitCode)"
    }   


}catch {
    <#Do this if a terminating exception happens#>
    write-Output "[$((Get-Date).TimeofDay)] [ERROR] Installing Winget Apps Failed"
}

