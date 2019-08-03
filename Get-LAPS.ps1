Param (
    [Parameter(mandatory=$true)][string]$Search = 'Search'
)
:loop while ($true){
    $Return = @{}
    $Return = @(Get-ADComputer -Filter "Name -like `"*$Search*`"" -Properties ms-Mcs-AdmPwd | Select Name,ms-Mcs-AdmPwd | out-string) 
    if($Return.Count -ge 1){
        $Return
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
}
