<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  <Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         Jeffery Field
  Creation Date:  5/1/24
  Purpose/Change: Initial script development
  
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

#[Initialisations]-------------------------------------------------------------------------------[Initialisations]--------------------------------------------------------------------------------[Initialisations]

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

$PSModuleAutoloadingPreference = 'All'


#[Declarations]-------------------------------------------------------------------------------[Declarations]--------------------------------------------------------------------------------[Declarations]
#Script Version
$ScriptVersion = "1.0"


#Script Info
$Scriptname = $MyInvocation.MyCommand.name
$Scriptpath = $myinvocation.mycommand.path
$FullScriptpath = $myinvocation.mycommand.PSCommandPath


#Log File Info
$LogPath = "C:\IT"
$LogName = "$Scriptname.log"
$LogFile = Join-Path -Path $LogPath -ChildPath $LogName

#Check log file size. Create a new one if it's larger than 10 MB.
[int]$LogFileSize = (Get-ChildItem -Path $LogFile | Select-Object -Property Name, @{Name = 'LengthInMB'; Expression = { [Math]::round($_.Length / 1MB,2) } }, Directory).LengthInMB

If($LogFileSize -ge "10"){
Start-Transcript -Path $LogPath\$LogName
Write-Host "Starting script $($Scriptname). With a new log."
}else{
Start-Transcript -Path $LogPath\$LogName -Append
Write-Host "Starting script $($Scriptname). Appending the log."
}


$Dir = Split-Path $scriptpath

If($Dir -like "*IMECache*" -or $Dir -like "*Microsoft Intune Management Extension*"){
Write-Host "Looks like this running from Intune. Going to switch to invocation"
Set-Location $Dir
}



#Write an event to the event log.
New-EventLog -source Intune-Script -LogName Application -Verbose -ErrorAction ignore
Write-EventLog -LogName "Application" -Source "Intune-Script" -EventID 1000 -EntryType Information -Message "Starting $($Scriptname)"


#[Functions]-------------------------------------------------------------------------------[Functions]--------------------------------------------------------------------------------[Functions]

#========== Check Admin Function ================

Function Global:Check-Admin {
<#  
.SYNOPSIS  
    Checks to see what context the script is running in.

.DESCRIPTION
    Checks to see what context the script is running in.

.EXAMPLE
    Check-Admin

.NOTES  
 Version : 1.0.0
 Author: Jeffery Field
 LastUpdate: 3/26/24 1:38 PM
 Source: Documents - Teammate Experience\Intune\Scripts
 Change Log:
#>

    [CmdletBinding()]  
 
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $Admin = (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

    If($Admin -eq "True"){
    $Global:Context = "Admin"
    return "Admin"
    }else{
    $Global:Context = "Standard"
    return "Standard"
    }
}



#[End]-------------------------------------------------------------------------------[End]--------------------------------------------------------------------------------[End]

$Variables = Get-Variable
Foreach($Variable in $Variables){Write-Host "Variable $($Variable.Name) is set to $($Variable.Value)"}

Stop-Transcript