#Load all scripts and display to user
cd (Get-Location).ProviderPath

#Load Functions
. \\internal.CONTOSO.com\resources\scripts\Modules\Search-Array.ps1

#Get-ScriptsList
$csv = Import-CSV .\Scripts.csv

:loop while ($true){
    Write-Host "Scripts:`n"
    $Choice = Search-Array($csv)
    #$Choice = $List[[int]$Choice]
    #$Choice = "$Choice"
    & $Choice.Path
    if ($Choice -eq "skip"){
        break loop
    }
}