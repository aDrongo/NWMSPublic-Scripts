<#
.SYNOPSIS
    Exports GPOs to current directory
.DESCRIPTION
    Get all GPOs
    foreach GPO 
        check modification date
        generate report
        check naming
        save report
.Parameter
    Path [String]
        Path for the folder to save items in, defaults to \\zeus\public\Internet Department\gpo\
    Date [DateTime]
        Date from when to export all modifed items, default example: (Get-Date).AddDays(-1)
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>

Function Export-GPOs(){

    Param(
        [String] $Path = "\\server\Internet Department\gpo\",
        [DateTime] $Date = $((Get-Date).AddDays(-1))
    )
    Write-Host "loaded"
    Write-Host "testing path $Path"
    If (!(Test-Path $Path)){
        Write-Host "creating path"
        New-Item -Path $Path -ItemType Directory -Force -Verbose
    }

    Write-Host "getting gpo's"
    $GPOs = Get-GPO -All
    foreach ($GPO in $GPOs){
        $i++
        Write-Host "checking modifcation date $($GPO.ModificationTime)"
        if ($($GPO.ModificationTime) -ge $Date){
            Write-Host "creating report for gpo:$($GPO.DisplayName)"
            $Report = $GPO | Get-GPOReport -ReportType Html -Verbose
            $Name = $GPO.DisplayName
            $Name = $Name -replace ":",""
            $Name = $Name -replace "/",""
            Write-Host "report created for gpo:$($Name)"
            Try{
                Write-Host "saving report"
                $Report | Out-File -FilePath "$($Path)$($Name).html" -Force -Verbose
            }
            Catch{
                Write-Host "failed saving report"
                Try{
                Write-Host "saving report"
                $Report | Out-File -FilePath "$($Path)$($GPO.Id).html" -Force -Verbose
                }
                Catch{
                Write-Host "double failed"
                $Report | Out-File -FilePath "$($Path)$($i)_Unkown.html" -Force -Verbose
                }
            }
        }
    }
}