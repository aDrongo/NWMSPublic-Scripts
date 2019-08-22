<#
 .Synopsis
  Finds a file

 .Description
  Finds a file in a specified path with a search term.
    Assign Parameters for Get-ChildItem
    Find Files, Select FullNames, Filter by Search term
    Return Files array

 .Parameter Path
  [String] Path to start search from

 .Parameter Search
  [String] Filter search by

 .Parameter Recurse
  [Boolean] For Recursive search

 .Parameter Exclude
  [String]Path or Files to exclude search from. Takes precedence over Search term.

 .Example
   # Finds a file in my documents with title 1on1
   Find-File -Path "$env:HOMEPATH\Documents" -Search "1on1"

 .NOTES
        Author     : Benjamin Gardner bgardner160@gmail.com
#>

Function Find-File{
    param(
    [string]$Path = "./",
    [string]$Search = ".*",
    [boolean]$Recurse = $True,
    [string]$Exclude = ""
    )

    $Parameters = @{
        'Path' = $Path
    }
    if($Recurse){
        $Parameters['Recurse'] = $True
    }
    if($Exclude){
        $Parameters['Exclude'] = $Exclude
    }

    $Files = $(Get-ChildItem @Parameters | Select FullName | Where-Object {$_ -match $Search}).FullName

    Return $Files
}

Export-ModuleMember -Function Find-File