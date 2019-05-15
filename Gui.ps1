#Load all scripts and display to user
cd (Get-Location).ProviderPath

#Load Functions
. .\Gui\Search-Dictionary.ps1

#Get Directory List
$DirList = Get-ChildItem ./*.ps1 -Recurse | sort -Property Name

#Create Dictionary from Directory List
$List = @{}
$i=0
Foreach ($Item in $DirList){
    $i++
    $List[[int]$($i)] = $($Item.Name -replace ".ps1")
}

:loop while ($true){
    Write-Host "Scripts:`n"
    $Choice = Search-Dictionary($List)

    $Choice = $List[[int]$Choice]
    $Choice = ".\$Choice.ps1"
    & $Choice
    if ($Choice -eq "skip"){
        break loop
    }
}