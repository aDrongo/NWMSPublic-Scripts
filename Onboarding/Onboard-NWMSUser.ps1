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
. \\internal.contoso.com\resources\scripts\Modules\DealerSocketSignature.ps1
. \\internal.contoso.com\resources\scripts\Modules\SyncADUserFromDealerMe.ps1

#Get Positions list
Try { $PositionsCsv = Get-Content \\internal.contoso.com\resources\scripts\Onboarding\Positions.csv | Select-String '^[^#]' -ErrorAction Stop } Catch { Write-Output "Error: $($Error[0])";Pause;Exit}
$Positions = New-Object System.Collections.ArrayList
Foreach ($Item in $PositionsCSV){
    $Item = $Item -split ","
    $Positions.add([PSCustomObject]@{Title = $Item[0]; Department = $Item[1]; SecurityGroup = $Item[2]; EmailGroup = $Item[3]; DealerMe = $Item[4]; Details = $Item[5]})
}

#Get Stores list
Try{ $StoresCsv = Get-Content \\internal.contoso.com\resources\scripts\Onboarding\Stores.csv | Select-String '^[^#]' -ErrorAction Stop } Catch { Write-Output "Error: $($Error[0])";Pause;Exit}
$Stores = New-Object System.Collections.ArrayList 
Foreach ($Item in $StoresCSV){
    $Item = $Item -split ","
    $Stores.add([PSCustomObject]@{Store = $Item[0]; OU = $Item[1]; Group = $Item[2]; City = $Item[3]; PO = $Item[4]; DealerMe = $Item[5]; SocketTeam = $Item[6]; SocketManager = $Item[7]})
}

cls

Write-Host("Logging to $logpath")

#endregion
#region section two - get user data

#Get Hire Status
$HireStatus = $null
While ($HireStatus -notmatch '[NRT]' -OR $HireStatus.Length -ne '1'){
    $HireStatus = $(Read-Host('Is this a new user(N) or re-hire(R) or transfer(T)? N/R/T'))
}

if($HireStatus -match '[RT]'){
    $User = Select-ADUser
    if($User){
        $FirstName = $User.GivenName
        $LastName = $User.Surname
        $Mobile = $(Get-ADUser -Identity $User.SamAccountName -Properties MobilePhone).MobilePhone
        $UPN = $User.UserPrincipalName
        $Sam = $User.SamAccountName
    }
    else{
        $HireStatus = "N"
    }
}

if($HireStatus -match '[N]'){
    #Get User Data
    $FirstName = $(Read-Host('Enter First Name'))
    Write-Output $FirstName
    $LastName = $(Read-Host('Enter Last Name'))
    Write-Output $LastName
    $Mobile = $(Read-Host('Enter Mobile'))
    Write-Output $Mobile
    $ID = $(Read-Host('Enter ID'))
    Write-Output $ID
    #Combine user data
    $FullName = $FirstName+' '+$LastName
    $Sam = ($FirstName+'.'+$LastName).ToLower()
    $UPN = $Sam+'@nwmotorsport.com'
}


#Generate Passwords
$PasswordforAD = GeneratePassword
$PasswordforKey = GeneratePassword
$PasswordforV = GeneratePassword

#Write output for Transcript records
Write-Output $PasswordforAD
Write-Output $PasswordforKey
Write-Output $PasswordforV


#Secure version for AD
$PasswordSecure = $PasswordforAD | ConvertTo-SecureString -AsPlainText -Force

#Get Users new Position
Write-Host "Please enter the matching index for their Position or 'skip' for manual creation"
$I = 0
Foreach ($Item in $Positions){
    $I++ 
    Write-Host "$I $($Item.Title)"
}
Do{ $PositionIndex = Read-Host "Index" } Until ($PositionIndex -in 1 .. $($Positions.Count) -OR $PositionIndex -match "skip")
if ($PositionIndex -notmatch "skip"){
    $Position = $Positions[$($PositionIndex - 1)]
    Write-Host "You selected: $($Position.Title)"
}
#Manually enter Title/Department
Else{
    $Position = New-Object System.Collections.ArrayList
    $Position.add([PSCustomObject]@{Title = $(Read-Host('Enter Title')); Department = $(Read-Host('Enter Department'))})
}


#Get Users new Store
Write-Host "Please enter the matching index for their Store"
$I = 0
Foreach ($Item in $Stores){
    $I++ 
    Write-Host "$I $($Item.Store)"
}
Do{ $StoreIndex = Read-Host "Index" } Until ($StoreIndex -in 1 .. $($Stores.Count))
$Store = $Stores[$($StoreIndex - 1)]
Write-Host "You selected: $($Store.Store)"

#Get OU Path from Store
$OUPath = "OU=$($Store.OU),OU=contoso Users,DC=internal,DC=contoso,DC=com"

#endregion
#region section three - set user

#If Re-Hire
if ($HireStatus -like 'R'){
    #Splat data for rehire
    $RehireUser = @{
            'ChangePasswordAtLogon' = $True
            'Enabled' = $True
    }
    #make changes to user
    Set-ADAccountPassword -Identity $User -NewPassword $PasswordSecure -Verbose
    $User | Set-ADUser @RehireUser -Verbose
    $User | Move-ADObject -TargetPath $OUPath -Verbose
    Set-ADuser -Identity $User.ObjectGUID.Guid -Replace @{msExchHideFromAddressLists="FALSE"} -verbose -ErrorAction SilentlyContinue
}

#If Transfer
if ($HireStatus -like 'T'){
    $User | Move-ADObject -TargetPath $OUPath -Verbose
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
            'UserPrincipalName' = $Sam+'@nwmotorsport.com'
            'AccountPassword' = $PasswordSecure
            'ChangePasswordAtLogon' = $True
            'Path' = $OUPath
            'Enabled' = $True
    }
    Write-Output $NewUser
    #Create User
    New-ADUser @NewUser -Verbose
    #Wait for user to be Created
    $I = 0
    Do{
    Write-Host "Checking for User Creation, Try: $I"
    Sleep $I
    $User = Get-ADUser -Identity $Sam
    $I++}
    Until($User)
}

#Remove existing groups
if ($HireStatus -match '[RT]'){
    $UserGroups = Get-ADUser -Identity $User.UserPrincipalName -Properties MemberOf
    Write-Host "Removing Groups"
    Foreach ($UserGroup in $UserGroups.MemberOf){
        Remove-ADGroupMember -Identity $UserGroup -Members $User.UserPrincipalName -Verbose -Confirm
    }
}

#Skip if custom Groups defined
if ($PositionIndex -notmatch "skip"){
    #Add to Groups
    Write-Host "Adding Groups"
    Add-ADGroupMember -Identity $($Position.SecurityGroup) -Members $User.UserPrincipalName -Verbose
    Add-ADGroupMember -Identity $($Store.Group+' '+$Position.EmailGroup) -Members $User.UserPrincipalName -Verbose
}

#endregion
#region section four - run smtp batch update, open worksheet, export selenium script

#Proxy Address Update script
If($(Read-Host('Run Directory Update? Y/N')) -match 'y'){
    invoke-item "\\zeus\public\Directory Maintainence\SMTP Batch Update.vbs"
    Write-Host "Proceed after directory update is complete"
}


#Sync changes to Azure
If($(Read-Host('Run Azure Sync? Y/N')) -match 'y'){
    Write-Host 'Invoking Start-ADSyncSyncCycle on contosoVS400'
    Invoke-Command -computername contosovs400 -scriptblock {Start-ADSyncSyncCycle} -Verbose -ErrorAction SilentlyContinue
}

#Set User License
If($(Read-Host('Assign License? Y/N?')) -match 'y'){
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    $license_choice = $null
    $license = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicense
    Do{
        $license_choice = Read-Host ("1. E3 License `n2. Office 365 License`nPlease enter Number")
    }
    Until($license_choice -match "1|2")
    if($license_choice -eq "1"){$license_sku = "ENTERPRISEPACK"}
    elseif($license_choice -eq "2"){$license_sku = "O365_BUSINESS_ESSENTIALS"}
    $license.SkuId = (Get-AzureADSubscribedSku | Where-Object -Property SkuPartNumber -Value $license_sku -EQ).SkuID
    $licenses = New-Object -TypeName Microsoft.Open.AzureAD.Model.AssignedLicenses
    $licenses.AddLicenses = $license
    Do{
        Try {
            Set-AzureADUser -ObjectId "$($User.UserPrincipalName)" -UsageLocation "US"
            Set-AzureADUserLicense -ObjectId "$($User.UserPrincipalName)" -AssignedLicenses $licenses -Verbose
            $SetAzureLicenseSuccess = "Yes" 
            }
        Catch {
            Write-Host "Failed:`n$($Error[0])"
            if($(Read-Host "Try Again? Y/N?") -match "N"){
                $SetAzureLicenseSuccess = "Cancel"
            }
        }
    }
    Until($SetAzureLicenseSuccess -match "Yes|Cancel")
}

#Add Azure groups
If($(Read-Host('Add Azure groups? Y/N?')) -match 'Y'){
    #Check if connected
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }

    $UserObjectID = (Get-AzureADUser -ObjectId $User.UserPrincipalName).ObjectID
    Add-AzureADGroupMember -ObjectId "b616d33c-57dc-4e9c-8a47-0a6b9732dd4b" -RefObjectId $UserObjectID -Verbose

    if($($Position.Title) -eq "Sales Representative"){
        Write-Host "Adding Sales Rep Team"
        Add-AzureADGroupMember -ObjectId "99f211fc-bae1-41ae-bb1f-2db2b755b5e9" -RefObjectId $UserObjectID -Verbose
    }
    if($($Position.Title) -eq "Sales Manager"){
        Write-Host "Adding Sales Manager Team"
        Add-AzureADGroupMember -ObjectId "eafb6a93-27b7-42c3-867c-c0cada0a377b" -RefObjectId $UserObjectID -Verbose
    }
    if($($Position.Title) -match "Finance"){
        Write-Host "Adding Finance Team"
        Add-AzureADGroupMember -ObjectId "7e4f1f39-cb87-4074-92fe-202b81d3195f" -RefObjectId $UserObjectID -Verbose
    }
}

if($(Read-Host "Continue creation in firefox? Y/N") -match "Y"){
    #Create Selenium script from template
    $Script = Get-Content "\\internal.contoso.com\resources\scripts\Onboarding\Onboard.side"
    $Script = $Script.Replace('$FirstName',"$($FirstName)")
    $Script = $Script.Replace('$LastName',"$($LastName)")
    $Script = $Script.Replace('$FullName',"$($FullName)")
    $Script = $Script.Replace('$Title',"$($Position.Title)")
    if($PositionIndex -notmatch "skip"){
      $Script = $Script.Replace('$Department',"$($Position.Department)")
      $Script = $Script.Replace('$DMeDepartment',"$($Position.DealerMe)")
      $Script = $Script.Replace('$Location',"$($Store.DealerMe)")
    }
    $Script = $Script.Replace('$team',"$($Store.SocketTeam)")
    $Script = $Script.Replace('$manager',"$($Store.SocketManager)")
    $Script = $Script.Replace('$Sam',"$($User.SamAccountName)")
    $Script = $Script.Replace('$Email',"$($User.UserPrincipalName)")
    $Script = $Script.Replace('$ID',"$($ID)")
    $Script = $Script.Replace('$PASSWORD2',"$($PasswordforV)")
    $Script = $Script.Replace('$PASSWORD3',"$($PasswordforKey)")
    #strip mobile number
    $MobileStrip = $Mobile -replace '[- )(]',""
    $Script = $Script.Replace('$Mobile',"$($MobileStrip)")
    #export script
    $Path = "\\internal.contoso.com\resources\scripts\Onboarding\Users\$($FullName).side"
    Write-Host "Selenium script exported to $Path"
    $Script | Out-File -FilePath $Path -Force -Verbose
    #Open browser to use Selenium
    Try{
        get-process -Name 'firefox' -ErrorAction Stop
    }
    Catch {
        Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe'
    }
}

#Open documentation sheet
if ($HireStatus -notmatch "T"){Invoke-Item "$($env:UserProfile)\contoso\IT Department - Documents\Employee Management\Employee Onboarding Worksheet NEW.dotx"}
else {Invoke-Item "$($env:UserProfile)\contoso\IT Department - Documents\Employee Management\Employee Transfer Worksheet.dotx"}

#Data to copy into sheet
$DataSheet = "
Name = $FullName
Mobile Number = $Mobile
Email Address = $($User.UserPrincipalName)
ID = $ID
Position = $($Position.Title)
Location = $($Store.Store)
SAM = $($User.SamAccountName)
OU = $($Store.OU)
$(if ($HireStaus -notmatch "T"){"AD Password = $PasswordforAD"})
Keytrak Password = $PasswordforKey
VAuto Password = $PasswordforV
Groups = $($Position.SecurityGroup)
Groups = $($Store.Group+' '+$Position.EmailGroup)
DealerSocket Name = Nw1$($FirstName[0])$Lastname
DealerSocket Team = $($Store.SocketTeam)
DealerSocket Manager = $($Store.SocketManager)
Details = $($Position.Details)
"
Echo $DataSheet
#save to temp
cd $env:TEMP
$DataSheet > "temp.txt"
#open temp data
invoke-item .\temp.txt

#endregion
#region section five - dealersocket sig

#Sync AD user with DealerMe
If($(Read-Host("Sync AD User from DealerMe? Y/N")) -match 'y'){
    $User | Sync-ADUserFromDealerMe
}

#Get DealerSocket Signature
If($(Read-Host('Continue with DealerSocket Signature? Y/N')) -match 'y'){
    $Signature = Get-DealerSocketSignature -Identity $User.SamAccountName
    Set-Clipboard $Signature
    Write-Host $Signature
    Write-Host ("DealerSocket Signature set to clipboard")
}
#endregion
Stop-Transcript
Pause
