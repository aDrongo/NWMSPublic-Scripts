#TODO: Screenshot
$Screenshot_Perm = Read-Host('Take Screen Shot? Y/N?')
if($Screenshot_Perm -match 'y'){
    $Screenshot_Job = Start-Job -ScriptBlock {
        Try{
            Add-Type -AssemblyName System.Windows.Forms,System.Drawing
            $path = "$env:USERPROFILE\Pictures\Screenshot-$(Get-Date -Format yyyyMMdd-HHmmss).png"
            $screens = [Windows.Forms.Screen]::AllScreens

            $top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
            $left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
            $width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
            $height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum

            $bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
            $bmp      = New-Object System.Drawing.Bitmap ([int]$bounds.width), ([int]$bounds.height)
            $graphics = [Drawing.Graphics]::FromImage($bmp)

            $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)

            $bmp.Save($path)

            $graphics.Dispose()
            $bmp.Dispose()
            Return $path
        }
        Catch{
            Return $False
        }
    }
}

#TODO: resource metrics
$MetricStats_Job = Start-Job -ScriptBlock {
    #Get-Counter -SampleInterval outputs objects so we use a Foreach loop to access each object's data and then pipe into Measure-Object
    #Get-Counter for Processor Time with Samples to average out
    $a = Get-Counter '\Processor(_Total)\% Processor Time' | Foreach-Object {$_.CounterSamples.CookedValue} | Measure-Object -Average
    #Round off the amounts
    $a.Average = [math]::Round($($a.Average))
    $a.Maximum = [math]::Round($($a.Maximum))
    #Get-Counter for RAM in bytes and round off.
    $b = Get-Counter '\Memory\Available Bytes' | Foreach-Object {$_.CounterSamples.CookedValue}
    $b = [math]::Round($([Int64]$b / 1048576))
    #Get-Counter for RAM in % then change to remaining memory.
    $c = Get-Counter '\Memory\% Committed Bytes In Use' | Foreach-Object {$_.CounterSamples.CookedValue}
    $c = [math]::Round($(100 - $c))
    #Get Disk Time active with Samples to average out
    $d = Get-Counter '\LogicalDisk(*)\% Disk Time'
    #Their are multiple Disks so we want to loop through each to get the most active then we average it out over the sample interval.
    $d_Max = @()
    Foreach ($object in $d){
        $d_Max += $($object.CounterSamples.CookedValue | Measure-Object -Max)
        }
    #Now average it out over the 5 samples taken and round it off.
    $d_Max = [math]::Round($($d_Max).Maximum,3)
    #Get-Counter Free Disk % and round off, we use -1 as their are multiple drives but the last one is always the Total.
    $e = Get-Counter '\LogicalDisk(*)\% Free Space' | Foreach-Object {$_.CounterSamples[-1].CookedValue}
    $e = [math]::Round([Int64]$e)
    #Get-Counter Free Disk in MB, we use -1 as their are multiple drives but the last one is always the Total.
    $f = Get-Counter '\LogicalDisk(*)\Free Megabytes' | Foreach-Object {$_.CounterSamples[-1].CookedValue}
    #Get-Counter Network Interface usage, convert from Bytes to Mbits and round off
    $g = Get-Counter '\Network Interface(*)\Bytes Total/sec' | Foreach-Object {$_.CounterSamples[0].CookedValue}
    $g = [math]::Round($($($g) / 104857),3)
    #Now we create our an object and attach the data
    $performance = New-Object -TypeName PSobject
    $performance | Add-Member -NotePropertyName "Processor Average" -NotePropertyValue "$($a.Average)%"
    $performance | Add-Member -NotePropertyName "Memory Free(MB)" -NotePropertyValue "$($b)MB"
    $performance | Add-Member -NotePropertyName "Memory Free(%)" -NotePropertyValue "$($c)%"
    $performance | Add-Member -NotePropertyName "Disk Max Time" -NotePropertyValue "$($d_Max) IOPS"
    $performance | Add-Member -NotePropertyName "Disk Free Space(%)" -NotePropertyValue "$($e)%"
    $performance | Add-Member -NotePropertyName "Disk Free Space(MB)" -NotePropertyValue "$($f)MB"
    $performance | Add-Member -NotePropertyName "Network Usage(Mb)" -NotePropertyValue "$($g)Mb"
    #Return the generated values
    Return $performance
}

$NetworkProcesses_Job = Start-Job -ScriptBlock {
    Get-NetTCPConnection -State Established,Listen | Select LocalPort,RemoteAddress,State,OwningProcess | Add-Member ScriptProperty -Name Name -Value {(Get-Process -id $($this.OwningProcess)).ProcessName} -passthru
}


#TODO: network stats
$NetworkConnectivity_Job = Start-Job -ScriptBlock {
    $Connections = @()
    $Connections += Test-NetConnection 8.8.8.8 | Select ComputerName,RemoteAddress,PingSucceeded -ExpandProperty PingReplyDetails | Select ComputerName,RemoteAddress,PingSucceeded,RoundtripTime
    $Connections += Test-NetConnection 10.0.0.1 | Select ComputerName,RemoteAddress,PingSucceeded -ExpandProperty PingReplyDetails | Select ComputerName,RemoteAddress,PingSucceeded,RoundtripTime
    $Connections += Test-NetConnection internal.contoso.com | Select ComputerName,RemoteAddress,PingSucceeded -ExpandProperty PingReplyDetails | Select ComputerName,RemoteAddress,PingSucceeded,RoundtripTime
    Return $Connections
}

#TODO: Get uptime
function Get-Uptime {
   $os = Get-WmiObject win32_operatingsystem
   $uptime = (Get-Date) - ($os.ConvertToDateTime($os.lastbootuptime))
   $Display = "$($Uptime.Days)" + " days, " + "$($Uptime.Hours)" + " hours, " + "$($Uptime.Minutes)" + " minutes"
   Return $Display
}
$Uptime = Get-Uptime

$CompName = $env:COMPUTERNAME
$UserName = $env:UserName
$IPName = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "loopback"}).IPAddress
$OSVersion = (Get-WmiObject win32_operatingsystem).Version
$BuildNumber = (Get-WmiObject win32_operatingsystem).BuildNumber

Try {
    $TV = (Get-itemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer\Version9\").ClientID
}
Catch {
    $TV = 'Unable to retrieve'
}

$Date = Get-Date

$Net = Get-NetIPConfiguration
$NetworkConfig = New-Object -TypeName PSobject
$NetworkConfig | Add-Member -NotePropertyName "InterfaceAlias" -NotePropertyValue $Net.InterfaceAlias
$NetworkConfig | Add-Member -NotePropertyName "InterfaceDescription" -NotePropertyValue $Net.InterfaceDescription
$NetworkConfig | Add-Member -NotePropertyName "Network Profile" -NotePropertyValue $Net.NetProfile.Name
$NetworkConfig | Add-Member -NotePropertyName "Default Gateway" -NotePropertyValue $Net.IPv4DefaultGateway.NextHop
$NetworkConfig | Add-Member -NotePropertyName "IPv4 Address" -NotePropertyValue $($Net.IPv4Address.IPAddress -join ",")
$NetworkConfig | Add-Member -NotePropertyName "DNS Servers" -NotePropertyValue $($Net.DNSServer.ServerAddresses -join ",")


$ProcessStats = Get-Process | Sort-Object CPU -Descending | Select CPU,Id,ProcessName,Path,PrivateMemorySize64,BasePriority,StartTime,Responding | Where {$_.CPU -ne $null}

$LogsApplication = Get-EventLog -LogName Application -Newest 5  | Select Index,Time,EntryType,Source,Message
$LogsSystem = Get-EventLog -LogName System -Newest 5 | Select Index,Time,EntryType,Source,Message

$GPOStats = gpresult /r
$GPOGroups = whoami /groups

$TimeStats = w32tm /query /status

$FirewallStatus = Get-NetFirewallProfile | Select Name,Enabled
$FirewallBlock = Get-NetFirewallRule | Where-Object {$_.Enabled -eq $True -and $_.Action -eq 'Block'} | Select DisplayName,Profile,Direction,Action

#Wait and collect jobs
if($Screenshot_Perm -match 'y'){
Write-Host 'Waiting on Screenshot'
$Screenshot_Job | Wait-Job
$Screenshot = Receive-Job $Screenshot_Job}
else{$Screenshot = "Permission denied"}


Write-Host 'Waiting on Network Connectivity test'
$NetworkConnectivity_Job | Wait-Job
$NetworkConnectivity = Receive-Job $NetworkConnectivity_Job | Select * -ExcludeProperty RunspaceId,PSComputerName,PSShowComputerName

Write-Host 'Waiting on Network Processes'
$NetworkProcesses_Job | Wait-Job
$NetworkProcesses = Receive-Job $NetworkProcesses_Job | Select * -ExcludeProperty RunspaceId,PSComputerName,PSShowComputerName

Write-Host 'Waiting on Metric Stats'
$MetricStats_Job  | Wait-Job
$MetricStats = Receive-Job $MetricStats_Job | Select * -ExcludeProperty RunspaceId,PSComputerName,PSShowComputerName
#TODO: spiceworks ticket/email

$UserInfo = New-Object -TypeName PSobject
$UserInfo | Add-Member -NotePropertyName HostName -NotePropertyValue $CompName
$UserInfo | Add-Member -NotePropertyName UserName -NotePropertyValue $UserName
$UserInfo | Add-Member -NotePropertyName IPAddress -NotePropertyValue $IPName
$UserInfo | Add-Member -NotePropertyName TeamViewer -NotePropertyValue $TV
$UserInfo | Add-Member -NotePropertyName Date -NotePropertyValue $Date
$UserInfo | Add-Member -NotePropertyName Uptime -NotePropertyValue $Uptime
$UserInfo | Add-Member -NotePropertyName OSVersion -NotePropertyValue $OSVersion
$UserInfo | Add-Member -NotePropertyName BuildNumber -NotePropertyValue $BuildNumber
$UserInfo | Add-Member -NotePropertyName Screenshot -NotePropertyValue $Screenshot

Function Convert-HTMLString($Test){
    foreach ($String in $Test){
        $TestOut = $TestOut + "<br>" + $String }
    Write-Output $TestOut
}

$convertParams = @{ 
 head = @"
<style>
body { background-color:#E5E4E2;
       font-family:Monospace;
       font-size:10pt; }
td, th { border:0px solid black; 
         border-collapse:collapse;
         white-space:pre; }
th { color:white;
     background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px ;white-space:pre; word-wrap: break-word; }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px;}
h2 {
 font-family:Tahoma;
 color:#6D7B8D;
}
div {
  word-wrap: break-word;
}
</style>
"@
}

$ResultsHTML = "<h1> Get-SystemInfo </h1>
<h3> User Info: </h3>
<p>$($UserInfo | ConvertTo-Html @convertParams)<br>
<h3> Network Connectivity: </h3>
$($NetworkConnectivity | ConvertTo-Html )<br>
<h3> Network Config: </h3>
$($NetworkConfig | ConvertTo-Html )<br>
<h3> Metric Stats: </h3>
$($MetricStats | ConvertTo-Html)<br>
<h3> System Processes: </h3>
$($ProcessStats | Sort CPU -Descending | ConvertTo-Html )<br>
<h3> Network Processes: </h3>
$($NetworkProcesses | ConvertTo-Html )<br>
<h3> GPO info: </h3>
$(Convert-HTMLString($GPOStats))<br>
$(Convert-HTMLString($GPOGroups))<br>
<h3> Time: </h3>
$(Convert-HTMLString($TimeStats))<br>
<h3> Firewall: </h3>
$($FirewallStatus | ConvertTo-Html )<br>
$(if($FirewallBlock){$($FirewallBlock | ConvertTo-Html )})
<h3>Application Logs:</h3>
$($LogsApplication | ConvertTo-Html )<br>
<h3>System Logs:</h3>
$($LogsSystem | ConvertTo-Html )<br></p>
"

$SavePath = "$env:USERPROFILE\Documents\Get-SystemInfo-$(Get-Date -Format yyyyMMdd-HHmmss).html"

$ResultsHTML | Out-File -FilePath $SavePath -Verbose
Invoke-Item $SavePath