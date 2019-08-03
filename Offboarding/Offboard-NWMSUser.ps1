<#
.SYNOPSIS
    Script to speed up offboarding proccess
.DESCRIPTION
    Find User
    Get Details and Groups
    Remove from Groups
    Disable User and Move OU
    Sync to Azure
    Open Word Document and Web pages to continue procedure
    Export-Mailbox
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>


#Start Log
$timestamp = Get-Date -Format FileDateTime
Try{
    $logpath = "\\internal.contoso.com\resources\scripts\Logs\Offboard-contosoUser\$($timestamp).txt"
    New-Item $logpath -Force -ErrorAction Stop
}
Catch {
    $logpath = "C:\Logs\Offboard-contosoUser\$($timestamp).txt"
    New-Item $logpath -Force
}
Start-Transcript -LiteralPath $logpath

Import-Module ActiveDirectory

Write-Host("Logging to $logpath")

#Get User Data
$FirstName = $(Read-Host('Enter First Name'))
Write-Output $FirstName
$LastName = $(Read-Host('Enter Last Name'))
Write-Output $LastName

#Create other user data from entered data
$FullName = $FirstName+' '+$LastName
$Sam = ($FirstName+'.'+$LastName).ToLower()

#Find User
$Found = 'No'
Try {
    $User = Get-ADUser -Identity $Sam -properties *
    foreach ($Object in $User){
        Write-Host("$($Object.DisplayName) | $($Object.SamAccountName)")
    }
    if ($(Read-Host('Is this the correct user? Y/N')) -match 'y'){
        $Found = "Yes"
    }
}
Catch {
    $Found = "No"
}
While ($Found -eq "No"){
    $Search= "*$(Read-Host('Enter Search term'))*"
    $User = Get-ADUser -Filter {Name -Like $Search}
    foreach ($Object in $User){
        Write-Host("$($Object.DisplayName) | $($Object.SamAccountName)")
    }
    if ($(Read-Host('Is the the correct user listed? Y/N')) -match 'y'){
        $Sam = Read-Host('Enter SAM Account Name')
        $User = Get-ADUser -Identity $Sam -properties *
        $Found = "Yes"
    }
}


#Get other user data
$Title = $User.Title
$Department = $User.Department

#Get Groups
$Groups = Get-ADPrincipalGroupMembership $Sam | Where-Object {$_.Name -notlike "Domain Users"}
Write-Host 'Found these Groups with user'
Write-Output $Groups

#Remove from Groups
Write-Host "Removing from Groups"
Foreach ($Group in $Groups){
    Remove-ADGroupMember -identity $Group.objectGUID -Members $Sam -Verbose
}

#OU to move to
$OUPath = "OU=Former Employees,OU=contoso Users,DC=internal,DC=contoso,DC=com"

#Set User as Disabled and in Former Employees OU
Write-Host 'Moving User OU and Disabling'
Set-ADUser -Identity $Sam -Enabled $False -Verbose
Move-ADObject -Identity $User.ObjectGUID.Guid -TargetPath $OUPath

# Hide user from global address list
Write-Host "Removing user from global address list (GAL)"
Try {
    Set-ADuser -Identity $User.ObjectGUID.Guid -Add @{msExchHideFromAddressLists="TRUE"}
}
Catch{
    Set-ADuser -Identity $User.ObjectGUID.Guid -Replace @{msExchHideFromAddressLists="TRUE"}
}

#Sync changes to Azure
Write-Host 'Invoking Start-ADSyncSyncCycle on contoso'
Invoke-Command -computername contoso -scriptblock {Start-ADSyncSyncCycle} -Verbose -ErrorAction SilentlyContinue

#Open sites to continue user removal
Write-Host('Opening sites to continue user offboarding')
[system.Diagnostics.Process]::Start("firefox","https://app.contoso.com/dealer/administrator/user")
[system.Diagnostics.Process]::Start("firefox","https://admin.microsoft.com/Adminportal/Home?source=applauncher#/homepage")
if ($Title -match "Sales"){
    [system.Diagnostics.Process]::Start("firefox","https://sales1")
    [system.Diagnostics.Process]::Start("firefox","https://sales2")
    [system.Diagnostics.Process]::Start("firefox","http://sales3")
    [system.Diagnostics.Process]::Start("firefox","https://sales4")
}
if ($Title -match "Sales Manager" -OR $Title -match "Finance"){
    [system.Diagnostics.Process]::Start("firefox","https://finance1")
    [system.Diagnostics.Process]::Start("firefox","https://finance2")
}

#Open documentation sheet
Invoke-Item "$env:UserProfile\OneDrive - contoso\Employee Management\Employee Separation Worksheet.dotx"

#Data to copy into sheet
$DataSheet = "
Name = $FullName
SAM = $Sam
Email Address = $($User.UserPrincipalName)
$(foreach ($Group in $Groups){
Write-Output ("Groups = $Group")
})
"
cd $env:TEMP
$DataSheet > "temp.txt"
invoke-item .\temp.txt

#Export Mailbox command
cd
if ($(Read-Host("Export Mailbox? Y/N")) -match "y"){
. \\internal.contoso.com\resources\scripts\Export-Mailbox.ps1
}

#Stop and wait for user
stop-transcript
pause
