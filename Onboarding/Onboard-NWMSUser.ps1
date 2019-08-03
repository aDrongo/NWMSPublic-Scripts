<#
.SYNOPSIS
    Script to create new users or rehires
.DESCRIPTION
    Import Functions
    Create Passwords
    Import Positions & Store, create Dictionaries
    Get User Data
    Select Position and Store
    If transfer Set Users
    If rehire Set User
    Else Create User
    Add to Groups if defined
    Run Exchange directory update script
    Import Selenium script template, replace variables and export
    Open Word Document and Web pages to continue creation
    Run AD directory update script
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>
#region section one - initialize

#Start Log
$timestamp = Get-Date -Format FileDateTime
Try{
    $logpath = "\\internal.contoso.com\resources\scripts\Logs\Onboard-contosoUser\$($timestamp).txt"
    New-Item $logpath -Force -ErrorAction Stop
}
Catch {
    $logpath = "C:\Logs\Onboard-contosoUser\$($timestamp).txt"
    New-Item $logpath -Force
}
Start-Transcript -LiteralPath $logpath

Import-Module ActiveDirectory

. \\internal.contoso.com\resources\scripts\Select-ADUser.ps1
. \\internal.contoso.com\resources\scripts\Modules\GeneratePassword.ps1
. \\internal.contoso.com\resources\scripts\Modules\Search-Dictionary.ps1
. \\internal.contoso.com\resources\scripts\Modules\DealerSocketSignature.ps1
. \\internal.contoso.com\resources\scripts\Modules\SyncADUserFromDealerMe.ps1

#Get Stores list from CSV
$csv = Get-Content \\internal.contoso.com\resources\scripts\Onboarding\Stores.csv | Select-String '^[^#]' | ConvertFrom-Csv -Delimiter ';'
$Stores = @{}
$i=0

#Convert CSV into Dictionary with values as an Array
foreach ($item in $csv){
    $i++
    $array = $($item.Value).split(',')
    $Stores[[int]$($i)] = $array
}

#Get Positions list from CSV
$csv = Get-Content \\internal.contoso.com\resources\scripts\Onboarding\Positions.csv | Select-String '^[^#]' | ConvertFrom-Csv -Delimiter ';'
$Positions = @{}
$i=0

#Convert CSV into Dictionary with values as an Array
foreach ($item in $csv){
    $i++
    $array = $($item.Value).split(',')
    $Positions[[int]$($i)] = $array
}
cls

Write-Host("Logging to $logpath")

#endregion
#region section two - get user data

#Get Hire Status
$HireStatus = $null
While ($HireStatus -notmatch '[NRT]'){
    $HireStatus = $(Read-Host('Is this a new user(N) or re-hire(R) or transfer(T)? N/R/T'))
}

#Get User Data
$FirstName = $(Read-Host('Enter First Name'))
Write-Output $FirstName
$LastName = $(Read-Host('Enter Last Name'))
Write-Output $LastName

if ($HireStatus -notmatch "T"){
  #Get extra data
  $Mobile = $(Read-Host('Enter Mobile'))
  Write-Output $Mobile
  $ID = $(Read-Host('Enter ID'))
  Write-Output $ID

  #Generate Passwords
  $Password1 = GeneratePassword
  $Password2 = GeneratePassword
  $Password3 = GeneratePassword

  #Write output for Transcript records
  Write-Output $Password1
  Write-Output $Password2
  Write-Output $Password3

  #Secure version for AD
  $PasswordSecure = $Password1 | ConvertTo-SecureString -AsPlainText -Force
}
#Combine user data
$FullName = $FirstName+' '+$LastName
$Sam = ($FirstName+'.'+$LastName).ToLower()
$UPN = $Sam+'@contoso.com'

#Get users Title from Dictionary, Search Dictionary and retrieve index with associated values, option to skip/create Title.
#Indexes are respectively Title, Department, Security Group, Distribution Group, DealerMe, Details
Write-Host 'Select a Title:'
$PositionNumber = Search-Dictionary($Positions)
if ($PositionNumber -notmatch "skip"){
    $Position = $Positions.$([int]$($PositionNumber))[0,1,2,3,4,5]
    Write-Host "You selected: $PositionNumber"
    Write-Host "Title:$($Position[0])"
}
#Option to Manually enter Title/Department
if ($PositionNumber -match "skip"){
    $Position = @($(Read-Host('Enter Title')),$(Read-Host('Enter Department')))
}

#Get Location from Dictionary, Search Dictionary and retrieve index with associated values
#Indexes are res[ectively OU,Group/Address,City,PO,DealerMe,Team,Manager
Write-Host 'Select a Store:'
$LocationIndex = Search-Dictionary($Stores)
$Location = $Stores.$([int]$($LocationIndex))[1,2,3,4,5,6]
$OU = $Stores.$([int]$($LocationIndex))[0]
Write-Host "You selected: $OU"

#Get OU Path from Location
$OUPath = "OU=$OU,OU=contoso Users,DC=internal,DC=contoso,DC=com"

#endregion
#region section three - set user

#If Re-Hire
if ($HireStatus -like 'R'){
    #Splat data for rehire
    $OldUser = @{
            'ChangePasswordAtLogon' = $True
            'Enabled' = $True
    }
    Write-Output $OldUser

    #Get user and make changes
    $User = @()
    Try {
        $User = Select-ADUser -Identity $FullName -ErrorAction Stop
        if ($(Read-Host('Procceed with this user? Y/N')) -match 'y'){
            $User | Set-ADUser @OldUser -Verbose
            Set-ADAccountPassword -Identity $User -NewPassword $PasswordSecure -Verbose
            $User | Move-ADObject -TargetPath $OUPath -Verbose
            Set-ADuser -Identity $User.ObjectGUID.Guid -Replace @{msExchHideFromAddressLists="FALSE"} -verbose -ErrorAction SilentlyContinue
        }
    }

    #If can't find user, allow them to create
    Catch {
        if ($(Read-Host("Couldn't find user. Create new user? Y/N")) -match 'y'){
            $HireStatus = 'N'
        }
        else {
            Write-Host('Nothing to do, exiting')
            sleep 5
            exit
        }
    }
}

#If Transfer
if ($HireStatus -like 'T'){
    #Get user and make changes
    $User = @()
    While ($User.count -le 1){
        $User = Select-ADUser -Identity $Sam
        if ($(Read-Host('Procceed with this user? Y/N')) -match 'y'){
            $User | Move-ADObject -TargetPath $OUPath -Verbose
        }
        else {
          $Sam = Read-Host('Enter a different Sam')
        }
    }
}

#If New Hire
if ($HireStatus -like 'N'){
    #Splat data for new user
    $NewUser = @{
            'SamAccountName' = $Sam
            'Name' = $FullName
            'GivenName' = $FirstName
            'Surname' = $LastName
            'DisplayName' = $FullName
            'UserPrincipalName' = $Sam+'@contoso.com'
            'AccountPassword' = $PasswordSecure
            'ChangePasswordAtLogon' = $True
            'Path' = $OUPath
            'Enabled' = $True
    }
    Write-Output $NewUser
    #Create User
    New-ADUser @NewUser -Verbose
}

#Select AD Object if not already selected
Try{
    if ($User.GetType().FullName -ne "Microsoft.ActiveDirectory.Management.ADUser"){
        $User = Select-ADUser -Identity $Sam
    }
}
Catch { $User = Select-ADUser -Identity $Sam }

#Skip if custom Groups defined
if ($PositionNumber -notmatch "skip"){
    #Add to Groups
    Add-ADGroupMember -Identity $Position[2] -Members $Sam -Verbose
    Add-ADGroupMember -Identity $($Location[0]+' '+$Position[3]) -Members $Sam -Verbose
}

#endregion
#region section four - run smtp batch update, open worksheet, export selenium script

#Proxy Address Update script
If($(Read-Host('Run Directory Update? Y/N')) -match 'y'){
    invoke-item "\\server\public\Directory Maintainence\SMTP Batch Update.vbs"
    Write-Host "Proceed after directory update"
}

#Create Selenium script from template
$Script = Get-Content "\\internal.contoso.com\resources\scripts\Onboarding\Onboard.side"
$Script = $Script.Replace('$FirstName',"$($FirstName)")
$Script = $Script.Replace('$LastName',"$($LastName)")
$Script = $Script.Replace('$FullName',"$($FullName)")
$Script = $Script.Replace('$Title',"$($Position[0])")
Try {
  $Script = $Script.Replace('$Department',"$($Position[3])")
}
Catch {Write-Ouput "Failed to add a Department"}
Try {
  $Script = $Script.Replace('$DMeDepartment',"$($Position[4])")
}
Catch {Write-Ouput "Failed to add a Dealer Me Department"}
Try {
  $Script = $Script.Replace('$Location',"$($Location[3])")
}
Catch {Write-Ouput "Failed to add a Location"}
$Script = $Script.Replace('$team',"$($Location[4])")
$Script = $Script.Replace('$manager',"$($Location[5])")
$Script = $Script.Replace('$Sam',"$($Sam)")
$Script = $Script.Replace('$Email',"$($UPN)")
if ($HireStatus -notmatch "T"){
  $Script = $Script.Replace('$ID',"$($ID)")
  $Script = $Script.Replace('$PASSWORD2',"$($Password2)")
  $Script = $Script.Replace('$PASSWORD3',"$($Password3)")
  #strip mobile number
  $MobileStrip = $Mobile -replace '[- )(]',""
  $Script = $Script.Replace('$Mobile',"$($MobileStrip)")
}

#Export script
$Path = "\\internal.contoso.com\resources\scripts\Onboarding\Users\$($FullName).side"
Write-Host "Selenium script exported to $Path"
$Script | Out-File -FilePath $Path -Force -Verbose

#Open browser to use Selenium
Try{
    get-process -Name 'firefox'
}
Catch {
    Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe'
}

#Open documentation sheet
if ($HireStatus -notmatch "T"){Invoke-Item "$($env:UserProfile)\contoso\IT Department - Documents\Employee Management\Employee Onboarding Worksheet.dotx"}
else {Invoke-Item "$($env:UserProfile)\contoso\IT Department - Documents\Employee Management\Employee Transfer Worksheet.dotx"}

#Data to copy into sheet
$DataSheet = "
Name = $FullName
Mobile Number = $Mobile
Email Address = $Upn
ID = $ID
Position = $($Position[0])
Location = $($Location[1]+' '+$Location[0])
SAM = $Sam
OU = $OU
AD Password = $Password1
Keytrak Password = $Password3
VAuto Password = $Password2
Groups = $($Position[2])
Groups = $($Location[0]+' '+$Position[3])
Sales Team = $($Location[4])
Sales Manager = $($Location[5])
Details = $($Position[5])
"
Echo $DataSheet
#save to temp
cd $env:TEMP
$DataSheet > "temp.txt"
#open temp data
invoke-item .\temp.txt

Write-Host "Please enable Mailbox first then DealerMe then other steps"
Write-Host "User shoud be granted: $($Position[5])"

#endregion
#region section five - dealersocket sig

#Sync AD user with Dealerme
If($(Read-Host("Update DealerMe before running this.`nRun AD Sync Update? Y/N")) -match 'y'){
    Sync-ADUserFromDealerMe -ADUser $User
    Write-Host "Proceed after AD Sync update"
}

#Get sales1 Signature
If($(Read-Host('Continue with Sales Signature? Y/N')) -match 'y'){
$Signature = Get-DealerSocketSignature -Identity $Sam
Set-Clipboard $Signature
Write-Host $Signature
Write-Host ("Sales Signature set to clipboard")
#open with Chrome because it's a stupid website
[system.Diagnostics.Process]::Start("chrome","Sales1")
}
#endregion
Stop-Transcript
Pause