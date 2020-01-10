Function Remove-Email{
    Start-Transcript
    # Note: Ensure you have the Powershell Exchange Online module, you can find this by opening Microsoft Edge and going to the Exchange Online admin center, clicking hybrid and then configure for the PS module.
    # Make it possible to connect to an IPPSSession (dot load the module to EXOPPSession)
    $CreateEXOPSSession = (Get-ChildItem -Path $env:userprofile -Filter CreateExoPSSession.ps1 -Recurse -ErrorAction SilentlyContinue -Force | Select -Last 1).DirectoryName
    . "$CreateEXOPSSession\CreateExoPSSession.ps1"
    
    # Connect to the IPPSSession (This will prompt for credentials)
    Connect-IPPSSession

    #Get Query String from User
    cls
    Write-Host "You are starting the remove-email process, please follow the below link for query syntax"
    Write-Host "https://docs.microsoft.com/en-us/sharepoint/dev/general-development/keyword-query-language-kql-syntax-reference?redirectedfrom=MSDN"
    Write-Host "Query Example: From:'azure@microsoft.com', Received:'Today', Subject:'Test'"
    Write-Host "Query Example: ‘virus’ AND ‘your account closure'"
    $Query = Read-Host "Enter Query"
    $SearchName = Read-Host "Enter Search Name"
    
    #Create Search
    $ComplianceSearch = New-ComplianceSearch -Name $SearchName -ExchangeLocation all -ContentMatchQuery $Query -Verbose
    #Start Search
    Start-ComplianceSearch -Identity $ComplianceSearch.Name -Verbose
    #Wait for Search
    Do{
        Write-Host "Waiting to complete..."
        Sleep 5
    }
    Until($(Get-ComplianceSearch -Identity $ComplianceSearch.Name).Status -eq 'Completed')
    #Inform User
    Write-Output $ComplianceSearch | Select Name,ContentMatchQuery,Items,JobEndTime,RunBy,Status

    #Return Search Result Count
    $Search = (Get-ComplianceSearch -Identity $ComplianceSearch.Name).SearchStatistics | ConvertFrom-Json
    Write-Host "Found $($Search.ExchangeBinding.Search.ContentItems) Occurances"
    if ($($Search.ExchangeBinding.Search.ContentItems) -gt 0){
        if ($(Read-Host ('Do you want to review occurances?" Y/N')) -match 'Y'){
            #split results for each line, search each line for item count greater than 1, return the matching values
            Write-Output (($Search.SuccessResults -split "Location:") | Select-String '[\S]+ Item count: [1-9]' -AllMatches | ForEach-Object {$_.Matches.Value})
            Write-Host ""
        }

        #Delete data found from Search
        If($(Read-Host('Proceed with Soft Deletion? Y/N')) -match 'Y'){
            $ComplianceAction = New-ComplianceSearchAction -SearchName $ComplianceSearch.Name -Purge -PurgeType SoftDelete -Verbose
            #Wait for delete
            Do{
                Write-Host "Waiting to complete..."
                Sleep 5
            }
            Until($(Get-ComplianceSearchAction -Identity $ComplianceAction.Name).Status -eq 'Completed')
            #Inform User
            Write-Output (Get-ComplianceSearchAction -Identity $ComplianceAction.Name)
        }
    }
    Stop-Transcript
}