#Weekly Report that get's AD User stats, hidden users, disabled but not moved users, oldest passwords, oldest logins, locked out accounts, accounts with no password expiring and admin accounts. Converts to HTML and emails report, schedule to run weekly.

Import-Module ActiveDirectory
Import-Module \\internal.contoso.com\resources\scripts\Modules\Get-ADUsersHidden
Import-Module \\internal.contoso.com\resources\scripts\Modules\ConvertHtml
Import-Module \\internal.contoso.com\resources\scripts\Private\Send-Mailcontoso

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

$UserEnabledCount = $(Get-ADUser -Filter "Enabled -eq '$true'" -SearchBase "OU=contoso Users,DC=internal,DC=contoso,DC=com").Count
$UserDisabledCount = $(Get-ADUser -Filter "Enabled -eq '$false'" -SearchBase "OU=contoso Users,DC=internal,DC=contoso,DC=com").Count
$ServiceEnabledCount = $(Get-ADUser -Filter "Enabled -eq '$true'").Count - $UserEnabledCount
$UserCount = New-Object PSObject
$UserCount | Add-Member -MemberType NoteProperty -Name 'Users Enabled' -Value $UserEnabledCount
$UserCount | Add-Member -MemberType NoteProperty -Name 'Users Disabled' -Value $UserDisabledCount
$UserCount | Add-Member -MemberType NoteProperty -Name 'Services Enabled' -Value $ServiceEnabledCount

#Hidden users
$ADUsersHidden = Get-ADUsersHidden
if(!$ADUsersHidden){$ADUsersHidden = "None"}

#Non-Disabled Former Employees
$NonDisabledFormer = Get-ADUser -Filter "Enabled -eq '$true'" -SearchBase "OU=Former Employees,OU=contoso Users,DC=internal,DC=contoso,DC=com"
if(!$NonDisabledFormer){$NonDisabledFormer = 'None'}

#Oldest Passwords
$OldestPasswords = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=contoso Users,DC=internal,DC=contoso,DC=com" -Properties PasswordLastSet | Sort-Object PasswordLastSet |where-object {$_.PasswordLastSet -ne $null} | select Name,SamAccountName,PasswordLastSet -First 10

#LastLogonDate
$LastLogonDate = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=contoso Users,DC=internal,DC=contoso,DC=com" -Properties LastLogonDate |where-object {$_.LastLogonDate -ne $null} | Sort-Object LastLogonDate | Select Name,SamAccountName,LastLogonDate -First 10

#Locked Out accounts
$LockedAccounts = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=contoso Users,DC=internal,DC=contoso,DC=com" -Properties LockedOut | Where-Object {$_.LockedOut -match 'True'}
if(!$LockedAccounts){$LockedAccounts = 'None'}

#Password Never expires
$NeverExpires = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=contoso Users,DC=internal,DC=contoso,DC=com" -Properties PasswordNeverExpires | Where-Object {$_.PasswordNeverExpires -match 'True'} | Select Name,SamAccountName,PasswordNeverExpires
if(!$NeverExpires){$NeverExpires = 'None'}

#Admin accounts
$AdminAccounts = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "DC=internal,DC=contoso,DC=com" -Properties AdminCount | Where-Object {$_.AdminCount -gt 0} | Select Name,SamAccountName,AdminCount | Add-Member -MemberType ScriptProperty -Name Groups -Value {$((Get-ADPrincipalGroupMembership $this.SamAccountName).name)} -PassThru

$body ="
<h1>AD User Report</h1>
<h3>User Counts:</h3>
$(ConvertHtml -intake $UserCount -convertParams $convertParams)
<h3>HiddenUsers:</h3>
$(ConvertHtml -intake $ADUsersHidden -convertParams $convertParams)
<h3>Non Disabled Former Users:</h3>
$(ConvertHtml -intake $NonDisabledFormer -convertParams $convertParams)
<h3>Oldest Passwords:</h3>
$(ConvertHtml -intake $OldestPasswords -convertParams $convertParams)
<h3>Last Logon Date:</h3>
$(ConvertHtml -intake $LastLogonDate -convertParams $convertParams)
<h3>Locked Accounts:</h3>
$(ConvertHtml -intake $LockedAccounts -convertParams $convertParams)
<h3>Password Never Expires:</h3>
$(ConvertHtml -intake $NeverExpires -convertParams $convertParams)
<h3>Admin Counts:</h3>
$(ConvertHtml -intake $AdminAccounts -convertParams $convertParams)
"

$to = "it@contoso.com"

Send-Mailcontoso -body $body -to $to