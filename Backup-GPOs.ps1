<#
.SYNOPSIS
    Backup GPOs by running Export-GPO and using git to backup the folder
.DESCRIPTION
    Run Export-GPOs
    Run Git to commit and push
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>

. \\internal.northwestmotorsportinc.com\resources\scripts\Modules\Export-GPOs.ps1

Export-GPOs

&  "C:\Program Files\Git\bin\bash.exe" --login -i -c "cd 'S:\Internet Department\gpo' && git add . && git commit -m 'daily backup'"
&  "C:\Program Files\Git\bin\bash.exe" --login -i -c "cd 'S:\Internet Department\gpo' && git push"