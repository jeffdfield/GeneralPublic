<#
.SYNOPSIS
  Ensures the device is in OOBE.
.DESCRIPTION
  Uses registry keys to determine if the device is in OOBE.
.PARAMETER <Parameter_Name>
    None
.INPUTS
  None
.OUTPUTS
  C:\UA_IT\OOBE-Requirement.log - Log file also returns In-OOBE or Not-In-OOBE
.NOTES
  Version:        3.0
  Author:         Jeffery Field
  Creation Date:  8/21/2025
  Purpose/Change: I re-wrote the script to use the new OOBE status functions and removed the old ones.
.EXAMPLE
  <Example goes here. Repeat this attribute for more than one example>
#>

Function Write-Log {

    <#
    .SYNOPSIS
    Function writes to log files so CMTrace can read them
    .DESCRIPTION
    Function writes to log files so CMTrace can read them
    .PARAMETER message
        The message you want to write to the log
    .PARAMETER component
        The component that wrote to the log
    .PArAMETER path
        The path of the log file, written like "c:\temp"
    .PARAMETER logname
        The name of the log, wirrent like "test.log"
    .INPUTS
    None
    .OUTPUTS
    Log file stated in the commandlet
    .NOTES
    Version:        1.0
    Author:         Jeffery Field
    Creation Date:  July 13th 2020
    Purpose/Change: Initial script development
    .EXAMPLE
    log-it -message "message testing" -component "One-X-Script" -path "C:\Temp\" -logname "test.log"
    #>

    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true)]
    [string]$message,
    [Parameter(Mandatory=$true)]
    [string]$component,
    [Parameter(Mandatory=$true)]
    [string]$path,
    [Parameter(Mandatory=$true)]
    [string]$logname,

    $thread = "0", $file = "N/A"
    )
    #Tests the folder path and creates it. If it can't create it we stop the script
    $Pathexists = test-Path $path
    if($Pathexists -eq $false){
        try{
        New-Item -Path $path -ItemType directory -Force
        }catch{
            Write-Host "unable to make log path"
            Start-Sleep -Seconds 15
            exit
            }
    }
    [string]$time = Get-Date -format "HH:mm:ss.fff+300"
    [string]$date = Get-Date -Format "MM-dd-yyyy"
    $a = "<![LOG["
    $b = "]LOG]!>"
    $carrot = "<"
    $closecarrot = ">"
    $c = "time=""$time"" date=""$date"" component=""$component"" context="""" type=""1"" thread=""$thread"" file=""$file"""
    $logentry =  $a+$message+$b+$carrot+$c+$closecarrot
    Add-Content -Path $path\$logname -Value $logentry
}



function Get-APStatus {
    [CmdletBinding()]

    $Global:APStatus = @()

    [bool]$DevicePrepComplete = $false
    [bool]$DeviceSetupComplete = $false
    [bool]$AccountSetupComplete = $false

    [string]$AutoPilotSettingsKey = 'HKLM:\SOFTWARE\Microsoft\Provisioning\AutopilotSettings'
    [string]$DevicePrepName = 'DevicePreparationCategory.Status'
    [string]$DeviceSetupName = 'DeviceSetupCategory.Status'
    [string]$AccountSetupName = 'AccountSetupCategory.Status'

    [string]$AutoPilotDiagnosticsKey = 'HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\AutoPilot'
    [string]$TenantIdName = 'CloudAssignedTenantId'

    [string]$JoinInfoKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\CloudDomainJoin\JoinInfo'

    [string]$CloudAssignedTenantID = (Get-ItemProperty -Path $AutoPilotDiagnosticsKey -Name $TenantIdName -ErrorAction 'Ignore').$TenantIdName

    if (-not [string]::IsNullOrEmpty($CloudAssignedTenantID)) {
        foreach ($Guid in (Get-ChildItem -Path $JoinInfoKey -ErrorAction 'Ignore')) {
            [string]$AzureADTenantId = (Get-ItemProperty -Path "$JoinInfoKey\$($Guid.PSChildName)" -Name 'TenantId' -ErrorAction 'Ignore').'TenantId'
        }

        if ($CloudAssignedTenantID -eq $AzureADTenantId) {
            $DevicePrepDetails = (Get-ItemProperty -Path $AutoPilotSettingsKey -Name $DevicePrepName -ErrorAction 'Ignore').$DevicePrepName
            $DeviceSetupDetails = (Get-ItemProperty -Path $AutoPilotSettingsKey -Name $DeviceSetupName -ErrorAction 'Ignore').$DeviceSetupName
            $AccountSetupDetails = (Get-ItemProperty -Path $AutoPilotSettingsKey -Name $AccountSetupName -ErrorAction 'Ignore').$AccountSetupName

            if (-not [string]::IsNullOrEmpty($DevicePrepDetails)) {
                $DevicePrepDetails = $DevicePrepDetails | ConvertFrom-Json
                $GMDevicePrepDetails = get-member -InputObject $DevicePrepDetails | Where-object {$_.Membertype -eq "NoteProperty" -and $_.Name -like "DevicePreparation.*"}
                $OverAllStatus = "$($DevicePrepDetails.categoryState) - $($DevicePrepDetails.CategoryStatusText)"

                Foreach($DevicePrepDetail in $GMDevicePrepDetails) {
                    $Obj = New-Object PSObject
                    $PropName = $DevicePrepDetail.Name.Split('.')[-1]
                    $StatusText = $DevicePrepDetails."$($DevicePrepDetail.Name)".Subcategorystatustext
                    $Status = $DevicePrepDetails."$($DevicePrepDetail.Name)".SubcategoryState
                    $Category = $DevicePrepDetail.Name.Split('.')[0]
                    

                    $Obj | Add-Member -MemberType NoteProperty -Name "Category" -Value $Category
                    $Obj | Add-Member -MemberType NoteProperty -Name "Step" -Value $PropName
                    $Obj | Add-Member -MemberType NoteProperty -Name "StatusText" -Value $StatusText
                    $Obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
                    $Obj | Add-Member -MemberType NoteProperty -Name "OverallStatus" -Value $OverAllStatus
                    
                    $Global:APStatus += $Obj
                }

            }else{
               return "Not-In-OOBE" 
            }
            if (-not [string]::IsNullOrEmpty($DeviceSetupDetails)) {
                $DeviceSetupDetails = $DeviceSetupDetails | ConvertFrom-Json
                $GMDeviceSetupDetails = get-member -InputObject $DeviceSetupDetails | Where-object {$_.Membertype -eq "NoteProperty" -and $_.Name -like "DeviceSetup.*"}
                $OverAllStatus = "$($DeviceSetupDetails.categoryState) - $($DeviceSetupDetails.CategoryStatusText)"


                Foreach($DeviceSetupDetail in $GMDeviceSetupDetails) {
                    $Obj = New-Object PSObject
                    $PropName = $DeviceSetupDetail.Name.Split('.')[-1]
                    $StatusText = $DeviceSetupDetails."$($DeviceSetupDetail.Name)".Subcategorystatustext
                    $Status = $DeviceSetupDetails."$($DeviceSetupDetail.Name)".SubcategoryState
                    $Category = $DeviceSetupDetail.Name.Split('.')[0]

                    $Obj | Add-Member -MemberType NoteProperty -Name "Category" -Value $Category
                    $Obj | Add-Member -MemberType NoteProperty -Name "Step" -Value $PropName
                    $Obj | Add-Member -MemberType NoteProperty -Name "StatusText" -Value $StatusText
                    $Obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
                    $Obj | Add-Member -MemberType NoteProperty -Name "OverallStatus" -Value $OverAllStatus
                    
                    $Global:APStatus += $Obj
                }
            }
            if (-not [string]::IsNullOrEmpty($AccountSetupDetails)) {
                $AccountSetupDetails = $AccountSetupDetails | ConvertFrom-Json
                $GMAccountSetupDetails = get-member -InputObject $AccountSetupDetails | Where-object {$_.Membertype -eq "NoteProperty" -and $_.Name -like "AccountSetup.*"}
                $OverAllStatus = "$($AccountSetupDetails.categoryState) - $($AccountSetupDetails.CategoryStatusText)"

                Foreach($AccountSetupDetail in $GMAccountSetupDetails) {
                    $Obj = New-Object PSObject
                    $PropName = $AccountSetupDetail.Name.Split('.')[-1]
                    $StatusText = $AccountSetupDetails."$($AccountSetupDetail.Name)".Subcategorystatustext
                    $Status = $AccountSetupDetails."$($AccountSetupDetail.Name)".SubcategoryState
                    $Category = $AccountSetupDetail.Name.Split('.')[0]

                    $Obj | Add-Member -MemberType NoteProperty -Name "Category" -Value $Category
                    $Obj | Add-Member -MemberType NoteProperty -Name "Step" -Value $PropName
                    $Obj | Add-Member -MemberType NoteProperty -Name "StatusText" -Value $StatusText
                    $Obj | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
                    $Obj | Add-Member -MemberType NoteProperty -Name "OverallStatus" -Value $OverAllStatus
                    
                    $Global:APStatus += $Obj
                }
            }
        }
        
    }
}

Get-APStatus

Write-Log -message "AutoPilot status is" -component "UA-Intune-Script" -path "C:\UA_IT\" -logname "OOBE-Requirement.log"
Write-Log -message " " -component "UA-Intune-Script" -path "C:\UA_IT\" -logname "OOBE-Requirement.log"
Foreach($Status in $Global:APStatus) {
    Write-Log -message "$($Status.Category) - $($Status.Step) - $($Status.Status) - $($Status.StatusText)" -component "UA-Intune-Script" -path "C:\UA_IT\" -logname "OOBE-Requirement.log"
}


if ($Global:APStatus.OverallStatus -like "*Failed*") {
    <# Action to perform if the condition is true #>
    Write-Log -message "AutoPilot has failed" -component "UA-Intune-Script" -path "C:\UA_IT\" -logname "OOBE-Requirement.log"
    $Global:IsAPRunning = "AP_Failed"
    return "Not-In-OOBE"
}

if ($Global:APStatus.Status -like "*InProgress*") {
    <# Action to perform if the condition is true #>
    $Global:IsAPRunning = "AP_Running"
    Write-Log -message "AutoPilot is running" -component "UA-Intune-Script" -path "C:\UA_IT\" -logname "OOBE-Requirement.log"
    return "In-OOBE"
}else {
    <# Action to perform if the condition is false #>
    $Global:IsAPRunning = "AP_Complete"
    Write-Log -message "AutoPilot is complete" -component "UA-Intune-Script" -path "C:\UA_IT\" -logname "OOBE-Requirement.log"
    return "Not-In-OOBE"
}