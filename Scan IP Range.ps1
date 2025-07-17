#This bit of code will scan a rang of IP addresses and return any Zebra devices. 
#This is also a good example of how to use .net to scan the range WAY faster than test-connection does. 


$ZebraMacs = @(
    "00:05:12",
    "00:15:70",
    "00:23:68",
    "40:83:DE",
    "48:8E:B7",
    "60:95:32",
    "78:B8:D6",
    "84:24:8D", 
    "88:BC:AC",
    "90:75:DE",
    "94:FB:29",
    "C4:7D:CC",
    "C8:1C:FE"
)

$ArrayOfHosts = 1..254 | ForEach-Object {"192.168.5.$_"}

$Tasks = $ArrayOfHosts | ForEach-Object {
    [System.Net.NetworkInformation.Ping]::new().SendPingAsync($_)
}

[Threading.Tasks.Task]::WaitAll($Tasks)

$AliveHosts = $Tasks.Result | Where-Object { $_.Status -eq "Success" }

$allivehosts

ForEach($Device in $AliveHosts) {
    $DeviceMac = (Get-NetNeighbor -IPAddress $_.Address).LinkLayerAddress
    Write-Output "[$((Get-Date).TimeofDay)] [INFO] MAC Address is $($macAddress)"
    $DeviceMac = $DeviceMac[0,8]
    If($ZebraMacs -contains $DeviceMac){
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Found Zebra Printer at IP: $($_.Address) with MAC: $($macAddress)"
        $ZebraDevices =+ $macAddress
    }else{
        Write-Output "[$((Get-Date).TimeofDay)] [INFO] Not a Zebra Printer. Continuing to next IP."
    }
}
