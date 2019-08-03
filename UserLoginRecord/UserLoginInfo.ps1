
#Get Date
$Date = Get-Date -format yyyyMMdd-HHmm
#Get IP
Try{
    $IP = $(Get-NetIPAddress -AddressFamily IPv4).IPAddress | where-object {$_ -match "10.4.*"}
}
Catch {
    $IP = 'Unable to retrieve'
}
#Get Comp Name
$CompName = $env:COMPUTERNAME
#Get User Name
$UserName = $env:UserName
#Get Teamviewer ID
Try {
    $TV = (Get-itemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer\Version9\").ClientID
}
Catch {
    $TV = 'Unable to retrieve'
}
#Combine variables into one string
$Out = "$CompName,$UserName,$TV,$Date,$IP"
#Output combined variable string to network folder and EventLogs, if fails record failure to EventLogs.
Try {
    Out-File -FilePath "\\server\Logs\LoginReports\$($CompName)$($Date).log" -InputObject $Out -ErrorAction Stop
    $Log = "LoginScript`nComputer: $CompName`nUser: $UserName`nTeamViewer: $TV`nDate: $Date`nIP: $IP"
    Write-EventLog -LogName Application -Source "Login Script" -EventID 1919 -Message "$Log"
}
Catch {
    Write-EventLog -LogName Application -Source "Login Script" -EventID 1502 -Message "UserLoginInfo failed to write out-file`n$($Error[0])"
}
