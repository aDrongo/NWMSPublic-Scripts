<#
.SYNOPSIS
    Script to search LoggedInUser Reports
.DESCRIPTION
    Load report logs
        Convert into CSV for searching
    Loop
        Foreach item in CSV
            check if item matches search
        return results
            offer to search again
                if not, break
        if no results
            offer to search again
                if not, break

.Parameter Search
    Search query against User names
.NOTES
        Author     : Benjamin Gardner bgardner160@gmail.com
#>
$progressBar = '|','/','-','\' 
#Load files
$Job = Start-Job -ScriptBlock {
    $Files = Get-ChildItem "\\server\Logs\LoginReports\" -Filter *.log
    $CSV = @()
    Foreach($File in $Files){
        $Content = @()
        $Content = $(Get-Content $File.FullName) -split ','
        $Properties = [ordered]@{
            ComputerName = $Content[0]
            UserName = $Content[1]
            TeamViewer = $Content[2]
            Date = $Content[3]
            IP = $Content[4]
        }
        $CSV += New-Object PSObject -Property $Properties
    }
    Write-Output $CSV
}
$Search = Read-Host ('Search')
$i = 0
While($Job.JobStateInfo.State -eq "Running"){
    $i++
    foreach ($string in $progressBar){
    Write-Progress -Activity "Loading $string`b" -Status "$($Job.JobStateInfo.State) $($Job.Name)" -SecondsRemaining -1
    Start-Sleep -Milliseconds 500
    }
}
$CSV = Receive-Job $Job
$Search
#Search Files
:loop while ($true){
    $Results = @()
    Foreach($Login in $CSV){
        if($Login.UserName -like "*$Search*"){
            $Results += $Login
        }
    }
    if($Results.Count -ge 1){
        $Results | sort Date -Descending | FT
        if($(Read-Host('Search again Y/N?')) -match 'n'){
            break loop
        }
        else {
            $Search = Read-Host ('Type search term')
        }
    }
    else{
        Write-Host "Couldn't find anything matching $Search"
        if($(Read-Host('Search again Y/N?')) -match 'n'){
            break loop
        }
        else {
            $Search = Read-Host ('Type search term')
        }
    }
    $Search = Read-Host ('Search')
}
