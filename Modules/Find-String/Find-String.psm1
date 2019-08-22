<#
 .Synopsis
  Finds files with a specified string

 .Description
  Finds a file in a specified path with a search term.
    Assign Parameters for Get-ChildItem
    Find Files, Select FullNames
    For each file, search for string
    add file and string containing search string to dictionary
    return dictionary

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
        If outputing to terminal, you may may want to Format List the output for readability.
        Author     : Benjamin Gardner bgardner160@gmail.com
#>


Function Find-String{
    param(
    [string]$Search = ".*",
    [string]$Path = "./",
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

    $Files = $(Get-ChildItem @Parameters | Select FullName).FullName

    $Output = @{}

    Foreach ($File in $Files){
        $Content = Get-Content $File -ErrorAction SilentlyContinue
        $Found = $Content | Out-String -Stream | Select-String $Search
        if ($Found){
            $Output += @{$File=$Found}
        }
    }

    Return $Output
}

Export-ModuleMember -Function Find-String