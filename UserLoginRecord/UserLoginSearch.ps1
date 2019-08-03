$Files = Get-ChildItem "\\server\Logs\LoginReports\" -Filter *.log

# Get logs and combine into CSV
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

#Function to search CSV for names
Function Search-UserLogin($CSV){
    :loop while ($true){
        $Search = Read-Host ('Type search term')
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
        }
        else{
            Write-Host "Couldn't find anything matching $Search"
            if($(Read-Host('Search again Y/N?')) -match 'n'){
                break loop
            }
        }
    }
}

#Search CSV
Search-UserLogin($CSV)