<# 
.SYNOPSIS
    Checks the status of a website
.DESCRIPTION
    Gets URL from user
    Checks DNS of that URL, stops if fails
    Invokes a webrequest for that URL
        If success
            gets timestamp
            reports to screen and increments $Up by +1
            Emits console beep
            sleeps for 5s
        If fails
            gets timestamp
            reports to screen
            if previous success checks checks if that success was in the last 30 seconds
                if not then it resets the $Up counter and success time
        if 3 consecutive success then exit
            
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>

$URL = Read-Host "Enter URL to check"
Resolve-DNSName $URL -ErrorAction Stop
Write-Host "`r"
$Up = $null
Do{
    try
    {
        if ($(Invoke-WebRequest -Uri $URL -UseBasicParsing -DisableKeepAlive -TimeoutSec 5).StatusCode -eq '200'){
            $SuccessTime = $(Get-Date -DisplayHint Time)
            Write-Host "Code(200): Site is OK!: $SuccessTime"
            $Up += 1
            Write-Host "Success: $Up/3"
            [console]::beep(1800,900)
            if ($Up -lt 3){sleep 5}
        }
     }
    catch [Net.WebException]
    {
        $FailedTime = $(Get-Date -DisplayHint Time)
        Write-Host "Code($([int]$_.Exception.Response.StatusCode)): No Response: $FailedTime"
        [console]::beep(600,300)
        if ($SuccessTime){
            if ($($FailedTime - $SuccessTime).Seconds -gt 30){
                $Up = 0
                $SuccessTime = $null
            }
        }
        sleep 5   
    }
}
Until ($Up -eq 3)
pause