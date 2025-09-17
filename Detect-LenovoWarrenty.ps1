
$Global:TypeInfo = @()
$Global:DeviceInfo = @()


function Get-TypeInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=1, Position=0)]
        [String]
        $SerialNumber
    )

    $TypeText = Invoke-WebRequest -Uri "https://pcsupport.lenovo.com/us/en/api/v4/mse/getproducts?productId=$SerialNumber" | Select-Object -ExpandProperty Content | ConvertFrom-Json | Select-Object -ExpandProperty Name

    $TypeNumber = ($TypeText -split 'Type ')[1]
    $TypeName = ($TypeText -split ' - ')[0]

    $TypeInfoDetails = [PSCustomObject]@{
        SerialNumber = $SerialNumber
        TypeName = $TypeName
    }

    $Global:TypeInfo += $TypeInfoDetails
    return $Global:TypeInfo
}


function Get-WarrantyEnd {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=1, Position=0)]
        [String]
        $SerialNumber,
        [switch]
        $Quiet
    )

    $Asset = Get-TypeInfo -SerialNumber $SerialNumber

    $data = @{"serialNumber"="$($Asset.SerialNumber)"; "country"="us"; "language"="en" }
    $json = $data | ConvertTo-Json

    $Response = Invoke-WebRequest -Uri "https://pcsupport.lenovo.com/us/en/api/v4/upsell/redport/getIbaseInfo" -ConnectionTimeoutSeconds 120 -OperationTimeoutSeconds 260 `
        -Method Post `
        -Headers @{
            "User-Agent"="Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:128.0) Gecko/20100101 Firefox/128.0";
            "Accept"="application/json, text/plain, */*";
            "Accept-Language"="en-US,en;q=0.5";
            "Content-Type"="application/json"} `
        -Body $json | Select-Object -ExpandProperty Content

    $WarrantyStart = $Response | ConvertFrom-Json | Select-Object -ExpandProperty Data | Select-Object -ExpandProperty baseWarranties | Select-Object -ExpandProperty startDate

    $WarrantyEnd = $Response | ConvertFrom-Json | Select-Object -ExpandProperty Data | Select-Object -ExpandProperty baseWarranties | Select-Object -ExpandProperty EndDate

    $Product = $Response | ConvertFrom-Json | Select-Object -ExpandProperty Data | Select-Object -ExpandProperty machineInfo | Select-Object -ExpandProperty product

    $Model = $Response | ConvertFrom-Json | Select-Object -ExpandProperty Data | Select-Object -ExpandProperty machineInfo | Select-Object -ExpandProperty model

    $ItemDetails = [PSCustomObject]@{
        SerialNumber = $($Global:TypeInfo.SerialNumber)
        WarrantyStart = $WarrantyStart[0]
        WarrantyEnd = $WarrantyEnd[0]
        Product = $Product
        Model = $Model
        TypeName = $($Global:TypeInfo.TypeName)
        TimeGenerated = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    }

    $Global:DeviceInfo += $ItemDetails
    

    If($Quiet){
        
    }Else{
        $DeviceInfo | Format-List
    }
}



$Make = (Get-WmiObject -Class Win32_ComputerSystem).Manufacturer
if ($Make -like "*LENOVO*") {

    $SerialNumber = Get-wmiobject -Class Win32_BIOS | Select-Object -ExpandProperty SerialNumber

    Get-WarrantyEnd -SerialNumber $SerialNumber -Quiet

    [datetime]$CD = Get-Date -Format "yyyy-MM-dd"

    if ($CD -gt $($DeviceInfo.WarrantyEnd[0])) {
        <# Action to perform if the condition is true #>
        #Write-Output "The warranty for Serial Number $($DeviceInfo.SerialNumber) has expired on $($DeviceInfo.WarrantyEnd[-1])."
        Exit 2
    }Else{
        #Write-Output "The warranty for Serial Number $($DeviceInfo.SerialNumber) is still valid until $($DeviceInfo.WarrantyEnd[-1])."
        Exit 0
    }

}else {
    #Write-Error "This script is intended for Lenovo systems only."
    Exit 0
}
