<#
.SYNOPSIS
    Backup GPOs by running Export-GPO and using git to backup the folder
.DESCRIPTION
    Look for last run log and import date, otherwise date is -24hrs
    Run Export-GPOs
    Run Git to commit and push
    Record run time
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>

. \\internal.CONTOSO.com\resources\scripts\Modules\Export-GPOs.ps1

#Look for last run log and import date, otherwise date is -24hrs
Try {
    $Date = [datetime]$(Get-Content -Path "\\contoso\Public\Internet Department\gpo\lastrun.log")
}
Catch {
    $Date = $((Get-Date).AddDays(-1))
}

#Export GPOs in the last 24 hrs.
Export-GPOs -Date $Date

#Record run date
$lastRun = Out-File -FilePath "\\contoso\Public\Internet Department\gpo\lastrun.log" -InputObject "$(Get-Date)" -Force

#This requires git to be configured on the computer with correct permissons and \\contoso\Public to be assigned S Drive.
&  "C:\Program Files\Git\bin\bash.exe" --login -i -c "cd 'S:\Internet Department\gpo' && git add . && git commit -m 'daily backup'"
&  "C:\Program Files\Git\bin\bash.exe" --login -i -c "cd 'S:\Internet Department\gpo' && git push"