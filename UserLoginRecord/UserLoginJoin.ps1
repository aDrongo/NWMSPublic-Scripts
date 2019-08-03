# Get list of logs
$Files = Get-ChildItem "\\server\Logs\LoginReports\" -Filter *.log
$Date = Get-Date -Format yyyyMMdd-HHmm
$Results = @()
# Combine contents of logs and combine into one CSV
# This needs to be replaced by a real database solution
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
    $Results += New-Object PSObject -Property $Properties
}
# Export results
$Results | Export-Csv -Path "\\server\Logs\LoginReports\Export-$Date.csv" -NoTypeInformation -Encoding UTF8