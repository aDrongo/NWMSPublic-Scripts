<# 
.SYNOPSIS
    #This script will return multiple remote computers Memory, Processor, Disk and Adapter Usage and email me
.DESCRIPTION
    #This script will return multiple remote computers Memory, Processor, Disk and Adapter Usage and email me
    #Foreach Computer loop
        #Invoke Command -AsJob
            #Get-Counters
            #Add to Hash
            #Return value
        #Add return values from jobs to HasH
    #Check AD Health
    #Check DCDiag
    #Wait for Jobs
    #Export results
    #Email results
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#.PARAMETER .LINK .EXAMPLE .INPUTTYPE .RETURNVALUE
#>
Using Module \\internal.contoso.com\resources\scripts\Modules\Logging
Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailServer
Import-Module \\internal.contoso.com\resources\scripts\Modules\Check-DuplicateADAttributes
Import-Module \\internal.contoso.com\resources\scripts\Modules\ConvertHtml

$Logger = [logging]::new()
$Logger.SetPublishPath("\\internal.contoso.com\resources\scripts\ServerReports\Logs\")

$ResultsPath = "\\internal.contoso.com\resources\scripts\ServerReports\ResultsLogs\"
$CsvPath = "\\internal.contoso.com\resources\scripts\ServerReports\MasterList.csv"
$HtmlPath = "\\internal.contoso.com\resources\scripts\ServerReports\HTMLLogs\$(Get-Date -Format yyyymmdd).html"

Try {
    $Csv = import-csv -Path $CsvPath
    $Logger.Log("Imported $CsvPath")
}
Catch {
    $Logger.Log($Error[0],5)
    $Logger.Publish()
    Throw $Error[0]
}

$Computers = @()
$InvokeJob = @()
$Failed = @()

Foreach ($Csvobject in $Csv) {
    #remote execute our script on the remote computers, run as job to run them all asynchronously.
    if(test-connection -count 1 -quiet -ComputerName $Csvobject.ComputerName){
        $Logger.Log("Connected to $($Csvobject.ComputerName)")
        $InvokeJob += Invoke-Command -ComputerName $Csvobject.ComputerName -AsJob -ErrorAction Stop {
            #Get-Counter -SampleInterval outputs objects so we use a Foreach loop to access each object's data and then pipe into Measure-Object
            #Processor Time with Samples to average out 
            $a = Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples 20 | Foreach-Object {$_.CounterSamples.CookedValue} | Measure-Object -Average -Maximum
            $a.Average = [math]::Round($($a.Average))
            $a.Maximum = [math]::Round($($a.Maximum))
            #RAM in bytes and round off.
            $b = Get-Counter '\Memory\Available Bytes' | Foreach-Object {$_.CounterSamples.CookedValue}
            $b = [math]::Round($([Int64]$b / 1048576))
            #RAM in % then change to remaining memory.
            $c = Get-Counter '\Memory\% Committed Bytes In Use' | Foreach-Object {$_.CounterSamples.CookedValue}
            $c = [math]::Round($(100 - $c))
            #Disk Time active with Samples to average out
            $d = Get-Counter '\LogicalDisk(*)\% Disk Time' -SampleInterval 1 -MaxSamples 20
            #Their are multiple Disks so we want to loop through each to get the most active then we average it out over the sample interval.
            $d_Max = @()
            Foreach ($object in $d){
                $d_Max += $($object.CounterSamples.CookedValue | Measure-Object -Max)
                }
            $Sum = 0
            Foreach ($Object in $d_Max){
                $Sum = $Sum + $Object.Maximum
                }
            $d_Average = [math]::Round($($sum / 20),3)
            #Free Disk % and round off, we use -1 as their are multiple drives but the last one is always the Total.
            $e = Get-Counter '\LogicalDisk(*)\% Free Space' | Foreach-Object {$_.CounterSamples[-1].CookedValue}
            $e = [math]::Round([Int64]$e)
            #Free Disk in MB, we use -1 as their are multiple drives but the last one is always the Total.
            $f = Get-Counter '\LogicalDisk(*)\Free Megabytes' | Foreach-Object {$_.CounterSamples[-1].CookedValue}
            #Network Interface usage, convert from Bytes to Mbits and round off
            $g = Get-Counter '\Network Interface(*)\Bytes Total/sec' | Foreach-Object {$_.CounterSamples[0].CookedValue}
            $g = [math]::Round($($($g) / 104857),3)
            $Performance = [ordered]@{
                Hostname = $env:COMPUTERNAME
                Processor_Average_Per = $a.Average
                Processor_Max_Per = $a.Maximum
                Memory_Free_MB = $b
                Memory_Free_Per = $c
                Disk_Avg_Time = $d_Average
                Disk_Free_Space_Per = $e
                Disk_Free_Space_MB = $f
                Network_Usage_Mb = $g
             }
            Return $Performance
        }
    }
    else { 
        $Logger.Log("Can't connect to $($Csvobject.ComputerName): $($Error[0])",4)
        $Failed += "Connection failed with" + $Csvobject.ComputerName 
    }
}


#Get Replication health
$DCs = $(Get-ADObject -LDAPFilter "(objectClass=computer)" -SearchBase "OU=Domain Controllers,DC=internal,DC=contoso,DC=com").Name
$Repl = @()
Foreach ($DC in $DCs){
    $Logger.Log("Retrieving data from $DC")
    Try{
        $Repl += Get-ADReplicationPartnerMetadata -Target $DC -Partition domain | Select @{n="Server";e={(($_.Server).Replace(".internal.contoso.com",""))}},@{n="Partner";e={(($_.Partner -split ',')[1].Replace("CN=",""))}},LastReplicationAttempt,LastReplicationSuccess,LastReplicationResult
        $Logger.Log('Got AD Replication Data')
    }
    Catch{
        $Logger.Log('Failed to Get AD Replication Data',3)
    }
}
#If we retrieved Replication lets make it pretty in HTML
if($Repl){
    [string]$Repl = $Repl | ConvertTo-Html -Fragment
    $i = 0
    $ReplSplit = @()
    $ReplOut = @()
    $ReplSplit = $Repl -split "<tr>"
    Foreach ($string in $ReplSplit){
        $i++
        if($i -le 2){
            $ReplOut += $string
            continue
        }
        elseif($i % 2){
            $ReplOut += $string.Insert(0,'<tr class="repl-odd">')
        }
        else{
            $ReplOut += $string.Insert(0,'<tr class="repl-even">')
        }
    }
    $ReplOut = $ReplOut -join ""
    $ReplOut = $ReplOut.Insert(60,'<tr><th colspan="5">AD Replication Summary</th></tr><tr>')
}
else{
    $ReplOut = "No Repl information"
}

#Get DC and run DCDiag.
Try{
    $LocalDC = Get-ADDomainController -Discover
    $Logger.Log("Get local DC: $LocalDC")
}
Catch { $Logger.Log("Failed to get LocalDC",3) }

if($LocalDC){
    $Logger.Log("Connecting to $($LocalDC.Name) to run DCDiag")
    if(Test-Connection $LocalDC.Name -Quiet){
        $Logger.Log("Running DCDiag")
        Try {
            $DCDiag = invoke-command -computername $LocalDC.Name -ScriptBlock { dcdiag /c /skip:KnowsOfRoleHolders /skip:CutoffServers /skip:RidManager /skip:OutboundSecureChannels /q } -ErrorAction Stop
        }
        Catch {
            $Logger.Log("Invoke Command failed: $($Error[0])",3)
        }
    }
    Else {
        $Logger.Log("Failed to contact $($LocalDC.Name)",3)
    }
}
Else { $DCDiag = "Failed to get DC"}

$DCDiag = ConvertHtml($DCDiag)

#Check for Duplicate AD Entries
Try{
    $Logger.Log("Checking Duplicate AD Attributes")
    $DuplicateADEntry = Check-DuplicateADAttributes
    if($DuplicateADEntry){$DuplicateADEntry = $DuplicateADEntry.GetEnumerator() | ConvertTo-Html -Fragment }
}
Catch { $Logger.Log($Error[0],3)}

$InvokeJob | Wait-Job

foreach ($Job in $InvokeJob){
    Try{
        $Performance = Receive-Job $Job -ErrorAction stop
        $Properties = [ordered]@{
            Hostname = $Performance.Hostname
            Processor_Average_Per = $Performance.Processor_Average_Per
            Processor_Max_Per = $Performance.Processor_Max_Per
            Memory_Free_MB = $Performance.Memory_Free_MB
            Memory_Free_Per = $Performance.Memory_Free_Per
            Disk_Avg_Time = $Performance.Disk_Avg_Time
            Disk_Free_Space_Per = $Performance.Disk_Free_Space_Per
            Disk_Free_Space_MB = $Performance.Disk_Free_Space_MB 
            Network_Usage_Mb = $Performance.Network_Usage_Mb
            }
        $Computers += New-Object PSObject -Property $Properties
        $Logger.Log("Job success on $($Job.Location)")
    }
    Catch {
        $Logger.Log("Job failed on $($Job.Location): $($Error[0])",4)
    }
}

Try{
    $ExportCSV = "$ResultsPath$(Get-Date -Format yyyyMMddhhmm).log"
    $Computers | Export-CSV -Path $ExportCSV -Encoding UTF8 -NoTypeInformation -Force
    $Logger.Log("Exported CSV to $ExportCSV")
    }
Catch{
    $logger.Log($Error[0],3)
}


. .\CSS.ps1

#Email Report
$Body = @"
<style type='text/css'>
.good { background-color: rgba(0,200,0,0.7); border-top: 0px solid black;}
.ok { background-color: rgba(200,200,0,0.7); border-top: 0px solid black;}
.bad { background-color: rgba(200,100,0,0.8); border-top: 0px solid black;}
.critical { background-color: rgba(250,0,0,0.9); border-top: 0px solid black;}
.name-odd { background-color: rgba(230,230,230,1); border-top: 0px solid black;  }
.name-even { background-color: rgba(255,255,255,1); border-top: 0px solid black; }
.repl-odd { background-color: rgb(230,230,230); border-top: 0px solid black; }
.repl-even { background-color: rgba(255,255,255,1); border-top: 0px solid black; }
body { font-family:Monospace; font-size:10pt; }
td { border-radius: 2px; text-align: right; }
th { color:white; background-color:black; }
td, th { border:0px solid black; border-collapse:collapse; }
table, tr, td, th { padding: 3px; margin: 0px ;white-space:pre; word-wrap: break-word; }
table { width:95%;margin-left:5px; margin-bottom:20px;}
</style>
<h2>Daily Server Report</h2>
<p>Executed on the following computer: $(Hostname) <br>
At this time: $(Get-Date) <br>
HTML Report can be found here:<a href='file:///$($HtmlPath.Replace("\","/"))'>$HtmlPath</a><br>
<table><tr><th> HostName </th><th> Processor Average </th><th> Memory Free </th><th> Memory Free </th><th> Disk Average Time </th><th> Disk Free Space </th><th> Disk Free Space </th>
$($i=0; foreach ($Item in $Computers) {
    "<tr><td style='text-align: left;' class=$(if($i % 2){"name-even"}else{"name-odd"})> $($Item.Hostname) </td>
    <td class=$(css-percentage($Item.Processor_Average_Per))> $($Item.Processor_Average_Per)% </td>
    <td class=$(css-mb($Item.Memory_Free_MB))> $($Item.Memory_Free_MB)MB </td>
    <td class=$(css-perc_rev($Item.Memory_Free_Per))> $($Item.Memory_Free_Per)% </td>
    <td class=$(css-percentage([int]$Item.Disk_Avg_Time))> $($Item.Disk_Avg_Time) </td>
    <td class=$(css-perc_rev($Item.Disk_Free_Space_Per))> $($Item.Disk_Free_Space_Per)% </td>
    <td class=$(css-disk($Item.Disk_Free_Space_MB))> $($Item.Disk_Free_Space_MB)MB </td>
    </tr>"
    $i++
})</table><br>
$ReplOut
<br>
<table>
<tr><th>DCDiag Error Report</tr></th>
<tr><td style='text-align: left;'>$($DCDiagout)</tr></td>
</table>
<br>
$(if($DuplicateADEntry){$DuplicateADEntry})<br>
For more logging information go to $($Logger.Path) <br>
"@
$Body | Out-File -FilePath $HtmlPath

$To = "wa.west.puyallup.400.internet.it@contoso.com,it@contoso.com"
#$To = 'ben.gardner@contoso.com' #For debuging

Try{
    Send-MailServer -body $Body -to $To  -subject "Report-Servers" -Verbose
    $Logger.Log("Sent Mail Message to $To")
}
Catch {
    $Logger.Log($Error[0],4)
}
$Logger.PublishLog()
