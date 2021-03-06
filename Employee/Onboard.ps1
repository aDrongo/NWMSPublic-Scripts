Using module \\internal.contoso.com\resources\scripts\Employee\Employee.psm1
Import-Module ActiveDirectory
Import-Module \\internal.contoso.com\resources\scripts\Employee\WordDoc.psm1
. \\internal.contoso.com\resources\scripts\Select-ADUser.ps1
. \\internal.contoso.com\resources\scripts\Modules\GeneratePassword.ps1
. \\internal.contoso.com\resources\scripts\Modules\DealerSocketSignature.ps1
. \\internal.contoso.com\resources\scripts\Modules\SyncADUserFromDealerMe.ps1
. \\internal.contoso.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1


#Start Log
$Timestamp = Get-Date -Format FileDateTime
$Logpath = "\\internal.contoso.com\resources\scripts\Logs\Onboard-ServerUser\$($Timestamp).log"
$Temppath = "$($env:TEMP)\$($Timestamp).log"
Start-Transcript -LiteralPath $Temppath

#Import Position/Services/Location map
$Structure = Get-Content "\\internal.contoso.com\resources\scripts\Employee\Structure.json" |  ConvertFrom-Json

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
    Write-Host "$($User.Name) : $($User.EmployeeNumber)"
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
    $NewGroups = $User.AddGroups($Structure.Service.'Active Directory')
}
else{
    $User = [Employee]::New($(Read-Host('Enter First Name')),$(Read-Host('Enter Last Name')), $(Read-Host('Enter ID')), $(Read-Host('Enter Mobile')))
    $User.AddPosition($Structure.Position)
    $User.AddLocation($Structure.Location)
    $User.AddOU($Structure.Service.'Active Directory'.OU)
    $User.CreateADUser($SecurePasswordforAD)
    $NewGroups = $User.AddGroups($Structure.Service.'Active Directory')
}

If($(Read-Host('Run Directory Update? Y/N')) -match 'y'){
    invoke-item "\\Server\public\Directory Maintainence\SMTP Batch Update.vbs"
    Write-Host "Proceed after directory update is complete"
}

If($(Read-Host('Run Azure Sync? Y/N')) -match 'y'){
    Write-Host 'Invoking Start-ADSyncSyncCycle on Server'
    Invoke-Command -computername Server -scriptblock {Start-ADSyncSyncCycle -PolicyType Delta -Verbose} -Verbose -ErrorAction SilentlyContinue
}

if($HireStatus -match '[N]'){
    If($(Read-Host("Add User to DealerMe? Y/N")) -match 'y'){
        if ($User.Title -match "Sales|Finance Manager"){
            $CreditEnabled = $True
            $Visibility = $True
            $MobileVisible = $True
        }
        else{ 
            $CreditEnabled = $False
            $Visibility = $False
            $MobileVisible = $False
        }
        $Location_Id = $Structure.Service.DealerMe.Location_Id.$($User.Location)
        $Department_Id = $Structure.Service.DealerMe.Department_Id.$($User.Security)
        [DealerMe]::AddUser($CreditEnabled,$Visibility,$MobileVisible,$Location_Id,$Department_Id,$User)
    }
}
elseif($HireStatus -match '[R]'){
    If($(Read-Host("Enable User in DealerMe? Y/N")) -match 'y'){
        if ($User.Security -match "Sales|Finance Manager"){
            $CreditEnabled = $True
            $Visibility = $True
            $MobileVisible = $True
        }
        else{ 
            $CreditEnabled = $False
            $Visibility = $False
            $MobileVisible = $False
        }
        $Location_Id = $Structure.Service.DealerMe.Location_Id.$($User.Location)
        $Department_Id = $Structure.Service.DealerMe.Department_Id.$($User.Security)
        Try{
            [DealerMe]::EnableUser($CreditEnabled,$Visibility,$MobileVisible,$Location_Id,$Department_Id,$User)
        }
        Catch [System.SystemException] {
            Write-Host "User not found"
            If($(Read-Host("User not found, Create? Y/N")) -match 'y'){
                [DealerMe]::AddUser($CreditEnabled,$Visibility,$MobileVisible,$Location_Id,$Department_Id,$User)
            }
        }
        Catch {
            $Error[0]
        }
    }
}
else{
    If($(Read-Host("Transfer User in DealerMe? Y/N")) -match 'y'){
        $Location_Id = $Structure.Service.DealerMe.Location_Id.$($User.Location)
        $Department_Id = $Structure.Service.DealerMe.Department_Id.$($User.Security)
        [DealerMe]::TransferUser($Location_Id,$Department_Id)
    }
}

If($(Read-Host('Assign O365 License? Y/N?')) -match 'y'){
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    $LicenseAssigned = [Azure]::AssignAzureLicense($User.UserPrincipalName, $User.License)
}

If($(Read-Host('Add Azure groups? Y/N?')) -match 'Y'){
    Try{ Get-AzureADTenantDetail -ErrorAction Stop 1> $null }
    Catch { Connect-AzureAD }
    [Azure]::AddAzureGroups($User.UserPrincipalName, $User.Title)
}

if($(Read-Host "Continue creation in firefox? Y/N") -match "Y"){
    #Create Selenium script from template
    if ($User.Title -match "Sales Manager|Finance Manager"){
        $Script = Get-Content "\\internal.contoso.com\resources\scripts\Employee\OnboardManager.side"
        $DSTeam = $($Structure.Service.DealerSocket.'Sales Manager'.Teams.$($User.Location))
        $DSManager = $($Structure.Service.DealerSocket.'Sales Manager'.Manager.$($User.Location))
        Write-Host "Password for RouteOne set to Clipboard"
        Set-Clipboard $PasswordforR
    }
    else {
        $Script = Get-Content "\\internal.contoso.com\resources\scripts\Employee\Onboard.side"
        $DSTeam = $($Structure.Service.DealerSocket.Sales.Teams.$($User.Location))
        $DSManager = $($Structure.Service.DealerSocket.Sales.Manager.$($User.Location))
    }
    $Script = $Script.Replace('$FirstName',"$($User.GivenName)")
    $Script = $Script.Replace('$LastName',"$($User.Surname)")
    $Script = $Script.Replace('$FullName',"$($User.Name)")
    $Script = $Script.Replace('$Title',"$($User.Title)")
    $Script = $Script.Replace('$DRLocation',"$($Structure.Service.DealerRater.Website.$($User.Location))")
    if($PositionIndex -notmatch "skip"){
      $Script = $Script.Replace('$DRDepartment',"$($Structure.Service.DealerRater.Department.$($User.Security))")
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
    $Path = "\\internal.contoso.com\resources\scripts\Employee\Users\$($User.Name).side"
    $Script | Out-File -FilePath $Path -Force -Verbose
    Write-Host " open selenium and import $Path"
    #Open browser to use Selenium
    Try{
        get-process -Name 'firefox' -ErrorAction Stop
    }
    Catch {
        Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe'
    }
    #Wait for Firefox to open
    sleep 2
    if ($Position.Title -match "Sales Manager"){
        [system.Diagnostics.Process]::Start("firefox","https://admin.microsoft.com/Adminportal/Home?source=applauncher#/homepage")
        [system.Diagnostics.Process]::Start("firefox","https://freesmsgateway.info/ ")
        Write-Host "Please create an SMS contact and add to Store SMS distribution group, also add the user to regional Shared Mailbox"
    }
    if ("RapidRecon" -in $User.Services){
        [system.Diagnostics.Process]::Start("firefox","$($Structure.Service.RapidRecon.$($User.Location).URL)")
    }
}

if($(Read-Host "Create Word Doc? Y/N") -match "Y"){
    #Open documentation sheet
    $Doc = $null
    if ($HireStatus -notmatch "T"){$Doc = OpenWordDoc("\\internal.contoso.com\resources\scripts\Employee\Onboarding.docx")}
    else {$Doc = OpenWordDoc("\\internal.contoso.com\resources\scripts\Employee\Transfer.docx")}
    ReplaceWordDocTag -Document $Doc -FindText "#Name" -ReplaceWithText $User.Name
    ReplaceWordDocTag -Document $Doc -FindText "#ID" -ReplaceWithText $User.EmployeeNumber
    ReplaceWordDocTag -Document $Doc -FindText "#Mobile" -ReplaceWithText $User.Mobile
    ReplaceWordDocTag -Document $Doc -FindText "#Mail" -ReplaceWithText $User.UserPrincipalName
    ReplaceWordDocTag -Document $Doc -FindText "#Date" -ReplaceWithText "$(Get-Date -format yyyy-MM-dd)"
    ReplaceWordDocTag -Document $Doc -FindText "#OldPosition" -ReplaceWithText $OldPosition
    ReplaceWordDocTag -Document $Doc -FindText "#Position" -ReplaceWithText $User.Title
    ReplaceWordDocTag -Document $Doc -FindText "#Location" -ReplaceWithText $User.Location
    ReplaceWordDocTag -Document $Doc -FindText "#Sam" -ReplaceWithText $User.SamAccountName
    ReplaceWordDocTag -Document $Doc -FindText "#Ou" -ReplaceWithText ($User.OU -split ',')[0].Replace('OU=','')
    ReplaceWordDocTag -Document $Doc -FindText "#OldOu" -ReplaceWithText ($OldOU -split ',')[0].Replace('OU=','')
    ReplaceWordDocTag -Document $Doc -FindText "#ADPassword" -ReplaceWithText $PasswordforAD
    ReplaceWordDocTag -Document $Doc -FindText "#CurrentGroups" -ReplaceWithText " "
    ReplaceWordDocTag -Document $Doc -FindText "#ADGroups" -ReplaceWithText ($NewGroups -join ",").Replace('CN=','')
    ReplaceWordDocTag -Document $Doc -FindText "#RemovedGroups" -ReplaceWithText ($RemovedGroups -join ",")
    ReplaceWordDocTag -Document $Doc -FindText "#License" -ReplaceWithText $LicenseAssigned
    if("Dealersocket" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#DSName" -ReplaceWithText "nw1$(($User.GivenName.ToLower()[0]))$(if($User.Surname.length -gt 5){$User.surname.tolower().Substring('0','6')}else{$User.surname.tolower()})"
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
    if("RapidRecon" -in $User.Services){
        ReplaceWordDocTag -Document $Doc -FindText "#RapidReconUser" -ReplaceWithText $User.SamAccountName
        ReplaceWordDocTag -Document $Doc -FindText "#RapidReconPassword" -ReplaceWithText $PasswordforR
        ReplaceWordDocTag -Document $Doc -FindText "#RapidReconURL"  -ReplaceWithText $($Structure.Service.RapidRecon.$($User.Location).URL)
    }
    Else{
        ReplaceWordDocTag -Document $Doc -FindText "#RapidReconUser" -ReplaceWithText " "
        ReplaceWordDocTag -Document $Doc -FindText "#RapidReconPassword"  -ReplaceWithText " "
        ReplaceWordDocTag -Document $Doc -FindText "#RapidReconURL"  -ReplaceWithText " "
        ReplaceWordDocTag -Document $Doc -FindText "#RapidRecon"  -ReplaceWithText " "
    }
    if ($HireStatus -notmatch "T"){
        $SaveFilePath = "\\Server\Employee Change Logs\New Setup\$($User.Name) $(Get-Date -format yyyy-MM-dd).docx"
    }
    else{
        $SaveFilePath = "\\Server\Employee Change Logs\Transfer\$($User.Name) $(Get-Date -format yyyy-MM-dd).docx"
    }
    SaveAsWordDoc -Document $Doc -FileName $SaveFilePath
    Invoke-Item $SaveFilePath
}

if($HireStatus -match "R|T"){
    If($(Read-Host("Disable DealerMe Services? Y/N")) -match 'y'){
        [DealerMe]::DisableUser($User)
    }
}

If($(Read-Host("Add DealerMe Services? Y/N")) -match 'y'){
    #Rapid Recon exception
    if ('RapidRecon' -in $User.Services){
        $User.Services = $User.Services | Where-Object {$_ -ne 'RapidRecon'}
        $User.Services += $($Structure.Service.RapidRecon.$($User.Location).Name)
    }
    [DealerMe]::AddServices($User)
}

If($(Read-Host("Sync AD User from DealerMe? Y/N")) -match 'y'){
    [DealerMe]::SyncADUser($User.SamAccountName)
}

if($User.Title -match "sales"){
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
Write-Host "Transcript copied to $LogPath"
Pause
Exit 0
