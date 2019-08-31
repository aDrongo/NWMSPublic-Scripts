#TODO: Screenshot
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
    #Now we create our hash table of properties
    $performance = [ordered]@{
        Processor_Average_Per = $a.Average
        Memory_Free_MB = $b
        Memory_Free_Per = $c
        Disk_Max_Time = $d_Max
        Disk_Free_Space_Per = $e
        Disk_Free_Space_MB = $f
        Network_Usage_Mb = $g
        }
    #Return the generated values
    Return $performance
}


#TODO: network stats
$NetworkStats_Job = Start-Job -ScriptBlock {
    $Connections = @()
    $Connections += Test-NetConnection 8.8.8.8 | Select RemoteAddress,PingSucceeded -ExpandProperty PingReplyDetails | Select RemoteAddress,PingSucceeded,RoundtripTime
    $Connections += Test-NetConnection 10.0.0.1 | Select RemoteAddress,PingSucceeded -ExpandProperty PingReplyDetails | Select RemoteAddress,PingSucceeded,RoundtripTime
    $Connections += Test-NetConnection internal.contoso.com | Select RemoteAddress,PingSucceeded -ExpandProperty PingReplyDetails | Select RemoteAddress,PingSucceeded,RoundtripTime
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

#TODO: Userinfo

$CompName = $env:COMPUTERNAME
$UserName = $env:UserName
$IPName = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notmatch "loopback"}).IPAddress
$OSVersion = (Get-WmiObject win32_operatingsystem).Version
$BuildNumber = (Get-WmiObject win32_operatingsystem).BuildNumber

#TODO: teamviewer id
Try {
    $TV = (Get-itemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer\Version9\").ClientID
}
Catch {
    $TV = 'Unable to retrieve'
}

$Date = Get-Date

#TODO: network config
$NetworkConfig = ipconfig /all

#TODO: proccess
$ProcessStats = Get-Process | Sort-Object CPU -Descending
#TODO: events
$LogsApplication = Get-EventLog -LogName Application -Newest 5
$LogsSystem = Get-EventLog -LogName System -Newest 5

#TODO: gpo
$GPOStats = gpresult /r
$GPOGroups = whoami /groups

#TODO: Timecheck
$TimeStats = w32tm /query /status

#Wait and collect jobs
$Screenshot_Job | Wait-Job
$Screenshot = Receive-Job $Screenshot_Job

$NetworkStats_Job | Wait-Job
$NetworkStats = Receive-Job $NetworkStats_Job

$MetricStats_Job  | Wait-Job
$MetricStats = Receive-Job $MetricStats_Job

#TODO: spiceworks ticket/email

#TODO: Results
$UserInfo = [ordered]@{
        Hostname = $CompName
        UserName = $UserName
        IP_Address = $IPName
        TeamViewer = $TV
        Date = $Date
        Uptime = $Uptime
        OSVersion = $OSVersion
        BuildNumber = $BuildNumber
        Screenshot = $Screenshot
        }

$Results = "
$($UserInfo | Out-String)`r
$($NetworkStats | FT | Out-String)`r
$($MetricStats | Out-String)`r
$($ProcessStats | Out-String)`r
$($GPOStats | Out-String)`r
$($GPOGroups | Out-String)`r
$($TimeStats | Out-String)`r
Application Logs:`n$($LogsApplication | Out-String)`r
System Logs:`n$($LogsSystem | Out-String)`r
"

Return $Results | ConvertTo-HTML