<# 
.SYNOPSIS
    Reports expiring passwords for AD Users in OUs
.DESCRIPTION
    Get Users in OUs
    Loop through Users
        check password
        if expiring
            email them
        record results
    Email IT Results
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#.PARAMETER .LINK .EXAMPLE .INPUTTYPE .RETURNVALUE
#>

Using Module \\internal.contoso.com\resources\scripts\Modules\Logging
Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailServer

$Logger = [Logging]::New()
$Logger.SetPublishPath("\\internal.contoso.com\resources\scripts\Logs\ExpiringPasswordEmail")

$Users = [System.Collections.ArrayList]@()
$Groups = ("Marketing","Internet Development","IT Department","Service Tech","Lot Technicians")
Foreach ($Group in $Groups){
    Try{
        $ADGroupMembers = Get-ADGroupMember -Identity $Group -ErrorAction Stop
        $Users.Add($ADGroupMembers)
    }
    Catch {
        $Logger.Log($Error[0],3)
    }
}
$Users = $Users | Select -unique

$Date = Get-Date -Format G
$Results = @()

Foreach ($User in $Users){
    Try{
        $Logger.Log("Get-ADUser $($User.SamAccountName)",1)
        $ADUser = Get-ADUser -identity $User.SamAccountName -Properties passwordlastset,passwordneverexpires,mail -ErrorAction Stop
    }
    Catch {
        $Logger.Log($Error[0],3)
    }
    if ($ADUser.PasswordLastSet -eq $Null){
        $Logger.Log("PasswordLastSet -eq Null",1)
        continue
    }
    if ($ADUser.Mail -eq $Null){
        $ADuser.Mail = $ADUser.GivenName+"."+$ADUser.Surname+"@contoso.com"
        $Logger.Log("Users Mail is Null",1)
    }
    if ($ADUser.PasswordNeverExpires -eq $False){
        $Logger.log("Password set to expire",1)
        $Diff = New-TimeSpan -start $ADUser.PasswordLastSet -end $Date
        $Remaining = 90-$($Diff.Days)
        $Expires = (Get-Date -Date(Get-Date).AddDays($Remaining) -DisplayHint Date | out-string).trim()
        $URL = "https://azkaban.internal.contoso.com/adfs/portal/updatepassword?username="+$ADUser.mail
        $emailed = "no"
        $to = $ADUser.mail
        if ($Diff.Days -ge 83 -AND $Diff.Days -le 90){
            $subject = "Your Windows password is expiring soon"
            $body = "<p>Your Windows password will expire on $Expires.<br>Please go to $URL to update your password.</p>"
        }
        elseif ($Diff.Days -gt 90){
            $subject = "Your Windows password has expired"
            $body = "<p>Your Windows password has expired, it is $Expired days overdue.<br>Please go to $URL to update your password.</p>"
        }
        else {
            $Logger.Log("No expiring passwords",1)
        }
        Try{ 
            Send-MailServer -body $body -to $to -subject $subject -ErrorAction Stop
            $emailed = "yes"
            $Logger.Log("Email Success",1)
        }
        Catch {
            $Logger.Log($Error[0],4)
        }
        $properties = @{
            User = $ADUser.Name
            PasswordLastSet = $ADUser.PasswordLastSet
            Expires = $Expires
            Emailed = $emailed
        }
        $Results += New-Object PSObject -Property $properties     
    }
    else {
        $Logger.Log("Password set to never expire,$User.SamAccountName",1)
    }
}

$convertParams = @{ 
 head = @"
<style>
body { background-color:#E5E4E2; font-family:Monospace; font-size:10pt; }
td, th { border:0px solid black; border-collapse:collapse; white-space:pre; }
th { color:white; background-color:black; }
table, tr, td, th { padding: 2px; margin: 0px ;white-space:pre; word-wrap: break-word; }
tr:nth-child(odd) {background-color: lightgray}
table { width:95%;margin-left:5px; margin-bottom:20px;}
div { word-wrap: break-word;}
</style>
"@
}

$to = "it@contoso.com"
$subject = "Password expiration report"
$body = "$($Results | ConvertTo-Html @convertParams)<footer>Logs at: $($Logger.Path)</footer>"
Try{ 
    Send-MailServer -body $body -to $to -subject $subject
    $Logger.Log("Email Report Sent",1)
}
Catch {
    $Logger.Log($Error[0],4)
}
$Logger.PublishLog()
