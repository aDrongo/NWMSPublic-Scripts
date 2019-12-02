Using module \\internal.contoso.com\resources\scripts\Onboarding\Employee.psm1
Import-Module ActiveDirectory
Import-Module \\internal.contoso.com\resources\scripts\Onboarding\WordDoc.psm1
. \\internal.contoso.com\resources\scripts\Select-ADUser.ps1
. \\internal.contoso.com\resources\scripts\Modules\GeneratePassword.ps1
. \\internal.contoso.com\resources\scripts\Modules\DealerSocketSignature.ps1
. \\internal.contoso.com\resources\scripts\Modules\SyncADUserFromDealerMe.ps1
. \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1


#Start Log
$Timestamp = Get-Date -Format FileDateTime
$Logpath = "\\internal.contoso.com\resources\scripts\Logs\Onboard-NWMSUser\$($Timestamp).log"
$Temppath = "$($env:TEMP)\$($Timestamp).log"
Start-Transcript -LiteralPath $Temppath

#Import Position/Services/Location map
$Structure = Get-Content "\\internal.contoso.com\resources\scripts\Onboarding\Structure.json" |  ConvertFrom-Json

#Generate Passwords
$PasswordforAD = GeneratePassword
$PasswordforKey = GeneratePassword
$PasswordforV = GeneratePassword
$PasswordforR = GeneratePassword
$SecurePasswordforAD = $PasswordforAD | ConvertTo-SecureString -AsPlainText -Force
Clear-Host

#Get Hire Status
$HireStatus = $null
While ($HireStatus -notmatch '[NRT]' -OR $HireStatus.Length -ne '1'){
    $HireStatus = $(Read-Host('Is this a new user(N) or re-hire(R) or transfer(T)? N/R/T'))
}

#Create User
if($HireStatus -match '[RT]'){
    $User = [Employee]::New()
    $User.GetADUser()
    Write-Host "$($User.GivenName) : $($User.EmployeeNumber)"
    $(if($(Read-Host("Mobile: $($User.Mobile)`nUpdate Mobile number? Y/N")) -match "Y"){$User.Mobile = Read-Host 'Enter mobile number'})
    $User.AddPosition($Structure.Position)
    $User.AddLocation($Structure.Location)
    $User.AddOU($Structure.Service.'Active Directory'.OU)
    if($HireStatus -match '[T]'){
        $OldOU = ((Get-ADUser -Identity $User.SamAccountName -Properties DistinguishedName) -split ",")[1].Replace("OU=",'')
        $OldPosition = $User.Title
        $User.TransferADUser()
    }
    elseif($HireStatus -match '[R]'){
        $User.EnableADUser($SecurePasswordforAD)
    }
    $RemovedGroups = $User.RemoveGroups()
    $NewGroups =$User.AddGroups($Structure.Service.'Active Directory'.'Distribution Group')
}
else{
    $User = [Employee]::New($(Read-Host('Enter First Name')),$(Read-Host('Enter Last Name')), $(Read-Host('Enter ID')), $(Read-Host('Enter Mobile')))
    $User.AddPosition($Structure.Position)
    $User.AddLocation($Structure.Location)
    $User.AddOU($Structure.Service.'Active Directory'.OU)
    $User.CreateADUser($SecurePasswordforAD)
    $NewGroup = $User.AddGroups($Structure.Service.'Active Directory'.'Distribution Group')
}

If($(Read-Host('Run Directory Update? Y/N')) -match 'y'){
    invoke-item "\\zeus\public\Directory Maintainence\SMTP Batch Update.vbs"
    Write-Host "Proceed after directory update is complete"
}

If($(Read-Host('Run Azure Sync? Y/N')) -match 'y'){
    Write-Host 'Invoking Start-ADSyncSyncCycle on NWMSVS400'
    Invoke-Command -computername nwmsvs400 -scriptblock {Start-ADSyncSyncCycle -PolicyType Delta -Verbose} -Verbose -ErrorAction SilentlyContinue
}

If($(Read-Host('Assign O365 License? Y/N?')) -match 'y'){
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    $LicenseAssigned = $User.AssignAzureLicense()
}

If($(Read-Host('Add Azure groups? Y/N?')) -match 'Y'){
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    $User.AddAzureGroups()
}

if($(Read-Host "Continue creation in firefox? Y/N") -match "Y"){
    #Create Selenium script from template
    if ($User.Position -match "Sales Managers|Finance Managers"){
        $Script = Get-Content "\\internal.contoso.com\resources\scripts\Onboarding\OnboardManager.side"
        $DSTeam = $($Structure.Service.DealerSocket.'Sales Manager'.Teams.$($User.Location))
        $DSManager = $($Structure.Service.DealerSocket.'Sales Manager'.Manager.$($User.Location))
        Write-Host "Password for RouteOne set to Clipboard"
        Set-Clipboard $PasswordforR
    }
    else {
        $Script = Get-Content "\\internal.contoso.com\resources\scripts\Onboarding\Onboard.side"
        $DSTeam = $($Structure.Service.DealerSocket.Sales.Teams.$($User.Location))
        $DSManager = $($Structure.Service.DealerSocket.Sales.Manager.$($User.Location))
    }
    $Script = $Script.Replace('$FirstName',"$($User.GivenName)")
    $Script = $Script.Replace('$LastName',"$($User.Surname)")
    $Script = $Script.Replace('$FullName',"$($User.Name)")
    $Script = $Script.Replace('$Title',"$($User.Position)")
    $Script = $Script.Replace('$DRLocation',"$($Structure.Service.DealerRater.Website.$($User.Location))")
    if($PositionIndex -notmatch "skip"){
      $Script = $Script.Replace('$DRDepartment',"$($Structure.Service.DealerRater.Department.$($User.Security))")
      $Script = $Script.Replace('$DMDepartment',"$($Structure.Service.DealerMe.Department.$($User.Security))") #Fix
      $Script = $Script.Replace('$DMLocation',"$($Structure.Service.DealerMe.Location.$($User.Location))")
      $Script = $Script.Replace('$KTDepartment',"$($Structure.Service.KeyTrak.$($User.Security))")
    }
    $Script = $Script.Replace('$team',"$DSTeam")
    $Script = $Script.Replace('$manager',"$DSManager")
    $Script = $Script.Replace('$Sam',"$($User.SamAccountName)")
    $Script = $Script.Replace('$Email',"$($User.UserPrincipalName)")
    $Script = $Script.Replace('$ID',"$($User.EmployeeNumber)")
    $Script = $Script.Replace('$PASSWORD2',"$($PasswordforV)")
    $Script = $Script.Replace('$PASSWORD3',"$($PasswordforKey)")
    #strip mobile number
    $MobileStrip = $User.Mobile -replace '[- )(]',""
    $Script = $Script.Replace('$Mobile',"$($MobileStrip)")
    #export script
    $Path = "\\internal.contoso.com\resources\scripts\Onboarding\Users\$($User.Name).side"
    Write-Host "Selenium script exported to $Path"
    $Script | Out-File -FilePath $Path -Force -Verbose
    #Open browser to use Selenium
    Try{
        get-process -Name 'firefox' -ErrorAction Stop
    }
    Catch {
        Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe'
    }
    if ($Position.Title -match "Sales Manager"){
    [system.Diagnostics.Process]::Start("firefox","https://admin.microsoft.com/Adminportal/Home?source=applauncher#/homepage")
    [system.Diagnostics.Process]::Start("firefox","https://freesmsgateway.info/ ")
    Write-Host "Please create an SMS contact and add to Store SMS distribution group, also add the user to regional Shared Mailbox"
    }
}

if($(Read-Host "Create Word Doc? Y/N") -match "Y"){
    #Open documentation sheet
    $Doc = $null
    if ($HireStatus -notmatch "T"){$Doc = OpenWordDoc("\\internal.contoso.com\resources\scripts\Onboarding\Onboarding.docx")}
    else {$Doc = OpenWordDoc("\\internal.contoso.com\resources\scripts\Onboarding\Transfer.docx")}
    ReplaceWordDocTag -Document $Doc -FindText "#Name" -ReplaceWithText $User.Name
    ReplaceWordDocTag -Document $Doc -FindText "#ID" -ReplaceWithText $User.EmployeeNumber
    ReplaceWordDocTag -Document $Doc -FindText "#Mobile" -ReplaceWithText $User.Mobile
    ReplaceWordDocTag -Document $Doc -FindText "#Mail" -ReplaceWithText $User.UserPrincipalName
    ReplaceWordDocTag -Document $Doc -FindText "#Date" -ReplaceWithText $(Get-Date -format MM-dd)
    ReplaceWordDocTag -Document $Doc -FindText "#OldPosition" -ReplaceWithText $OldPosition
    ReplaceWordDocTag -Document $Doc -FindText "#Position" -ReplaceWithText $User.Position
    ReplaceWordDocTag -Document $Doc -FindText "#Location" -ReplaceWithText $User.Location
    ReplaceWordDocTag -Document $Doc -FindText "#Sam" -ReplaceWithText $User.SamAccountName
    ReplaceWordDocTag -Document $Doc -FindText "#Ou" -ReplaceWithText $User.OU
    ReplaceWordDocTag -Document $Doc -FindText "#OldOu" -ReplaceWithText $OldOU
    ReplaceWordDocTag -Document $Doc -FindText "#ADPassword" -ReplaceWithText $PasswordforAD
    ReplaceWordDocTag -Document $Doc -FindText "#CurrentGroups" -ReplaceWithText " "
    ReplaceWordDocTag -Document $Doc -FindText "#ADGroups" -ReplaceWithText ($NewGroups -join ",")
    ReplaceWordDocTag -Document $Doc -FindText "#RemovedGroups" -ReplaceWithText ($RemovedGroups -join ",")
    ReplaceWordDocTag -Document $Doc -FindText "#License" -ReplaceWithText $LicenseAssigned
    if("Dealersocket" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#DSName" -ReplaceWithText "nw1$(($User.GivenName.ToLower()[0]))$($User.surname.tolower().Substring('0','6'))"
        ReplaceWordDocTag -Document $Doc -FindText "#DSTeam" -ReplaceWithText $DSTeam
        ReplaceWordDocTag -Document $Doc -FindText "#DSManager" -ReplaceWithText $DSManager
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#DSName" -ReplaceWithText ""
        ReplaceWordDocTag -Document $Doc -FindText "#DSTeam" -ReplaceWithText ""
        ReplaceWordDocTag -Document $Doc -FindText "#DSManager" -ReplaceWithText ""
    }
    if("KeyTrak" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#KeytrakUser" -ReplaceWithText $User.SamAccountName
        ReplaceWordDocTag -Document $Doc -FindText "#KeytrakPassword" -ReplaceWithText $PasswordforKey
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#KeytrakUser" -ReplaceWithText " "
        ReplaceWordDocTag -Document $Doc -FindText "#KeytrakPassword" -ReplaceWithText " "
    }
    if("VAuto" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#VAutoUser" -ReplaceWithText $User.SamAccountName
        ReplaceWordDocTag -Document $Doc -FindText "#VAutoPassword" -ReplaceWithText $PasswordforV
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#VAutoUser" -ReplaceWithText " "
        ReplaceWordDocTag -Document $Doc -FindText "#VAutoPassword" -ReplaceWithText " "
    }
    if("DealerRater" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#DealerRater" -ReplaceWithText $User.UserPrincipalName
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#DealerRater" -ReplaceWithText " "
    }
    if("CUDL" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#CUDL" -ReplaceWithText $User.UserPrincipalName
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#CUDL" -ReplaceWithText " "
    }
    if("RouteOne" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#RouteOneUser" -ReplaceWithText $User.SamAccountName
        ReplaceWordDocTag -Document $Doc -FindText "#RouteOnePassword" -ReplaceWithText $PasswordforR
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#RouteOneUser" -ReplaceWithText " "
        ReplaceWordDocTag -Document $Doc -FindText "#RouteOnePassword" -ReplaceWithText " "
    }
    if ($HireStatus -notmatch "T"){
        $SaveFilePath = "\\zeus\Employee Change Logs\New Setup\$($User.Name) $(Get-Date -format yyyy-MM-dd).docx"
    }
    else{
        $SaveFilePath = "\\zeus\Employee Change Logs\Transfer\$($User.Name) $(Get-Date -format yyyy-MM-dd).docx"
    }
    SaveAsWordDoc -Document $Doc -FileName $SaveFilePath
    Invoke-Item $SaveFilePath
}

If($(Read-Host("Sync AD User from DealerMe? Y/N")) -match 'y'){
    $User.SyncADUserFromDealerMe()
}

If($(Read-Host("Add DealerMe Services? Y/N")) -match 'y'){
    $User.AddDealerMeServices()
}


if($User.Position -match "sales"){
    If($(Read-Host('Get DealerSocket Signature? Y/N')) -match 'y'){
        $Signature = Get-DealerSocketSignature -Identity $User.SamAccountName
        Set-Clipboard $Signature
        Write-Host $Signature
        Write-Host ("DealerSocket Signature set to clipboard")
        start-process -FilePath 'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe' -ArgumentList 'https://bb.dealersocket.com/#/crm/admin/dealership-setup/dealership-users'
    }
}

Stop-Transcript
Copy-Item -Path $TempPath -Destination $LogPath
Pause
