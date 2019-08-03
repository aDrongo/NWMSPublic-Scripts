$List = Import-CSV -Path .\Scripts.csv
Write-Output $List
$OptOut = $null
While($OptOut -ne "Yes"){
    $Choice = $(Read-Host('Do you want to add or remove a script? A/R'))
    if($Choice -match "A"){
        $ScriptName = Read-Host('Enter Script Name')
        $ScriptPath = Read-Host('Enter Script Path, relative or full')
        $Hash = @{
            Name = $ScriptName
            Path = $ScriptPath
        }
        $List += New-Object PSObject -Property $Hash
    }
    if($Choice -match "R"){
        $ScriptRemove = Read-Host('Enter Script to remove')
        $List = $List | Where-Object {$_.Name -notlike "$ScriptRemove"}
    }
    if($(Read-Host('Do you want to edit another or save? Blank or S')) -match "S"){
        $OptOut = "Yes"
    }
}
$List | Export-Csv -Path .\Scripts.csv -NoTypeInformation