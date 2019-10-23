#Weekly Report

Import-Module ActiveDirectory
Import-Module \\internal.contosoinc.com\resources\scripts\Modules\Get-ADUsersHidden
Import-Module \\internal.contosoinc.com\resources\scripts\Modules\ConvertHtml
Import-Module \\internal.contosoinc.com\resources\scripts\Modules\Private\Send-Mailnwms
Import-Module \\internal.contosoinc.com\resources\scripts\Modules\Execute-Command

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

$UserEnabledCount = $(Get-ADUser -Filter "Enabled -eq '$true'" -SearchBase "OU=NWMS Users,DC=internal,DC=contosoinc,DC=com").Count
$UserDisabledCount = $(Get-ADUser -Filter "Enabled -eq '$false'" -SearchBase "OU=NWMS Users,DC=internal,DC=contosoinc,DC=com").Count
$ServiceEnabledCount = $(Get-ADUser -Filter "Enabled -eq '$true'").Count - $UserEnabledCount
$UserCount = New-Object PSObject
$UserCount | Add-Member -MemberType NoteProperty -Name 'Users Enabled' -Value $UserEnabledCount
$UserCount | Add-Member -MemberType NoteProperty -Name 'Users Disabled' -Value $UserDisabledCount
$UserCount | Add-Member -MemberType NoteProperty -Name 'Services Enabled' -Value $ServiceEnabledCount

#Get Azure Licensing Sku Counts
Try{
    #Need to run this command as 64bit(jenkins runs as 32bit) so call external 64bit powershell and return output
    $EnterpriseSkuCount = Execute-Command -commandTitle "Get-AzureSkuCount" -commandPath "$($env:SystemRoot)\sysnative\WindowsPowerShell\v1.0\powershell.exe" -commandArguments '& {Import-Module \\internal.contosoinc.com\resources\scripts\Modules\Private\Get-AzureSkuCount; $AzureCount = Get-AzureSkuCount; Return $AzureCount | Where SkuPartNumber -match "ENTERPRISEPACK"}'
    $EnterpriseSkuCount = $EnterpriseSkuCount.stdout

    $BusinessSkuCount = Execute-Command -commandTitle "Get-AzureSkuCount" -commandPath "$($env:SystemRoot)\sysnative\WindowsPowerShell\v1.0\powershell.exe" -commandArguments '& {Import-Module \\internal.contosoinc.com\resources\scripts\Modules\Private\Get-AzureSkuCount; $AzureCount = Get-AzureSkuCount; Return $AzureCount | Where SkuPartNumber -match "O365_BUSINESS_ESSENTIALS"}'
    $BusinessSkuCount = $BusinessSkuCount.stdout

    #Output is a string so need to parse it
    $EnterpriseSkuCount = $EnterpriseSkuCount.Split([Environment]::NewLine)
    $EnterpriseConsumed = $($EnterpriseSkuCount | Select-String -Pattern "ConsumedUnits").ToString() -replace '[\D]*',""
    $EnterpriseEnabled = $($EnterpriseSkuCount | Select-String -Pattern "Enabled").ToString() -replace '[\D]*',""

    $BusinessSkuCount = $BusinessSkuCount.Split([Environment]::NewLine)
    $BusinessConsumed = $($BusinessSkuCount | Select-String -Pattern "ConsumedUnits").ToString() -replace '[\D]*',""
    $BusinessEnabled = $($BusinessSkuCount | Select-String -Pattern "Enabled").ToString() -replace '[\D]*',""

    $UserCount | Add-Member -MemberType NoteProperty -Name "E3 Enterprise" -Value "$($EnterpriseConsumed)/$($EnterpriseEnabled)"
    $UserCount | Add-Member -MemberType NoteProperty -Name "Business Essentials" -Value "$($BusinessConsumed)/$($BusinessEnabled)"
}
Catch{
    $UserCount | Add-Member -MemberType NoteProperty -Name 'Azure License Count' -Value "Error getting License Count"
}

#Hidden users
$ADUsersHidden = Get-ADUsersHidden | Select Name,SamAccountName,Title,Department,LastLogonDate
if(!$ADUsersHidden){$ADUsersHidden = "None"}

#Non-Disabled Former Employees
$NonDisabledFormer = Get-ADUser -Filter "Enabled -eq '$true'" -SearchBase "OU=Former Employees,OU=NWMS Users,DC=internal,DC=contosoinc,DC=com" | Select Name,SamAccountName,Title,Department,LastLogonDate
if(!$NonDisabledFormer){$NonDisabledFormer = 'None'}

#Oldest Passwords
$OldestPasswords = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=NWMS Users,DC=internal,DC=contosoinc,DC=com" -Properties PasswordLastSet,Title,Department | Sort-Object PasswordLastSet |where-object {$_.PasswordLastSet -ne $null} | select Name,SamAccountName,Title,Department,PasswordLastSet -First 10

#LastLogonDate
$LastLogonDate = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=NWMS Users,DC=internal,DC=contosoinc,DC=com" -Properties LastLogonDate,Title,Department |where-object {$_.LastLogonDate -ne $null} | Sort-Object LastLogonDate | Select Name,SamAccountName,Title,Department,LastLogonDate -First 10

#Locked Out accounts
$LockedAccounts = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=NWMS Users,DC=internal,DC=contosoinc,DC=com" -Properties LockedOut | Where-Object {$_.LockedOut -match 'True'} | Select Name,SamAccountName,Title,Department,LastLogonDate,PasswordLastSet,LockedOut
if(!$LockedAccounts){$LockedAccounts = 'None'}

#Password Never expires
$NeverExpires = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "OU=NWMS Users,DC=internal,DC=contosoinc,DC=com" -Properties PasswordNeverExpires | Where-Object {$_.PasswordNeverExpires -match 'True'} | Select Name,SamAccountName,PasswordNeverExpires
if(!$NeverExpires){$NeverExpires = 'None'}

#Admin accounts
$AdminAccounts = Get-ADUser -Filter 'Enabled -eq $True' -SearchBase "DC=internal,DC=contosoinc,DC=com" -Properties AdminCount | Where-Object {$_.AdminCount -gt 0} | Select Name,SamAccountName,AdminCount | Add-Member -MemberType ScriptProperty -Name Groups -Value {$((Get-ADPrincipalGroupMembership $this.SamAccountName).name)} -PassThru

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

Send-Mailnwms -body $body -to $to -subject "Report-ADUser"