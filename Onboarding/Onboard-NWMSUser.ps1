<#
.SYNOPSIS
    Script to create new users or rehires
.DESCRIPTION
    Define Functions
    Create Passwords
    Import Positions & Store Dictionary
    Get User Data
    Select Position and Store
    Create or Set AD User
    Add to Groups if defined
    Run Exchange directory update script
    Import Selenium script template, replace variables and export
    Open Word Document and Web pages to continue creation
    Run AD directory update script
.NOTES
     Author     : Benjamin Gardner bgardner160@gmail.com
#>


#Start Log
$timestamp = Get-Date -Format FileDateTime
Try{
    $logpath = "\\internal.contoso.com\resources\scripts\Logs\Onboard-NWMSUser\$($timestamp).txt"
    New-Item $logpath -Force -ErrorAction Stop
}
Catch {
    $logpath = "C:\Logs\Onboard-NWMSUser\$($timestamp).txt"
    New-Item $logpath -Force
}
Start-Transcript -LiteralPath $logpath

Import-Module ActiveDirectory


#Search Function for Dictionaries
Function Search-Dictionary($Dictionary) {
    #Write Dictionary for user to view
    Write-Host $($Dictionary | Out-String)
    #Loop untill valid result
    :loop while ($true){
        #Get User input
        $Number = $(Read-Host('Enter No. or "search" or "skip"'))
        #check user input
        if ($Number -notmatch "^[0-9]*$" -AND $Number -notmatch "search" -AND $Number -notmatch "skip"){
            Write-Host "Invalid input"
        }
        #If valid move to next
        else {
            break loop
        }
    }
    #If Search selected
    if ($Number -match 'search'){
        #loop untill valid result
        :loop while ($true){
            #search result dictionary
            $Result = [ordered]@{}
            $Search = Read-Host ('Type search term')
            #Loop through Keys in dictionary, pair keys to values and evalute the values against search term, if match then store in Result dictionary
            foreach ($Key in $Dictionary.keys){
                $Value = $Dictionary.$($Key)[0]
                if ($Value -like "*$Search*"){
                    $Result += @{"$Key" = $Dictionary.$($Key)}
                }
            }
            #If Results contains values then present to user and get them to select or search again
            if($Result.Count -ge 1){
                Write-Host $($Result | Out-String)
                $Number = $(Read-Host('Enter No. or "search"'))
                #if user input valid then break loop
                if ($Number -match "^[0-9]*$"){
                    break loop
                }
            }
            #Else let user know no results and get to search again
            else{
                Write-Host "Couldn't find anything matching $Search"
                if($(Read-Host('Search again Y/N?')) -match 'n'){
                $Number = 'skip'
                break loop}
            }
        }
    }
    return $Number
}


#Random character function for Password
function Get-RandomCharacters($length, $characters) { 
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length } 
    $private:ofs="" 
    return [String]$characters[$random]
}

#Generate a Password
function GeneratePassword(){
    $Password = Get-RandomCharacters -length 6 -characters 'abcdefghikmnoprtuvwxyz'
    $Password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNPRTUVWXYZ'
    $Password += Get-RandomCharacters -length 1 -characters '1234567890'
    Return $Password
}


$Password1 = GeneratePassword
$Password2 = GeneratePassword
$Password3 = GeneratePassword

#For Transcript
Write-Output $Password1
Write-Output $Password2
Write-Output $Password3
#Secure version for AD
$PasswordSecure = $Password1 | ConvertTo-SecureString -AsPlainText -Force


#Create Stores Dictionary
#CSV Import and ignore comment line
$csv = Get-Content \\internal.contoso.com\resources\scripts\Onboarding\Stores.csv | Select-String '^[^#]' | ConvertFrom-Csv -Delimiter ';'
$Stores = @{}
$i=0

#Convert CSV into Dictionary with values as an Array
foreach ($item in $csv){
    $i++
    $array = $($item.Value).split(',')
    $Stores[[int]$($i)] = $array
}

#Create Positions Dictionary
#CSV Import and ignore comment line
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


######
#Body#
######

Write-Host("Logging to $logpath")

#Get Hire Status
$HireStatus = $null
While ($HireStatus -notmatch 'N' -AND $HireStatus -notmatch 'R'){
    $HireStatus = $(Read-Host('Is this a new user(N) or re-hire(R)? N/R'))
}

#Get User Data
$FirstName = $(Read-Host('Enter First Name'))
Write-Output $FirstName
$LastName = $(Read-Host('Enter Last Name'))
Write-Output $LastName
$Mobile = $(Read-Host('Enter Mobile'))
Write-Output $Mobile
$ID = $(Read-Host('Enter ID'))
Write-Output $ID

#Create other user data from entered data
$FullName = $FirstName+' '+$LastName
$Sam = ($FirstName+'.'+$LastName).ToLower()
$UPN = $Sam+'@nwmotorsport.com'

#Get users Title from Dictionary, Search Dictionary and retrieve index with associated values, option to skip/create Title.
Write-Host 'Select a Title:'
$PositionNumber = Search-Dictionary($Positions)
if ($PositionNumber -notmatch "skip"){
    $Position = $Positions.$([int]$($PositionNumber))[0,1,2,3,4]
    Write-Host "You selected: $PositionNumber"
    Write-Host "Title:$($Position[0])"
}
#Option to Manually enter Title/Department
if ($PositionNumber -match "skip"){
    $Position = @($(Read-Host('Enter Title')),$(Read-Host('Enter Department')))
}

#Get Location from Dictionary, Search Dictionary and retrieve index with associated values
Write-Host 'Select a Store:'
$LocationIndex = Search-Dictionary($Stores)
$Location = $Stores.$([int]$($LocationIndex))[1,2,3,4]
Write-Host "You selected: $LocationIndex"
Write-Host "Location: $Location"

#Get OU Path from Location
$OU = $Stores.$([int]$($LocationIndex))[0]
$OUPath = "OU=$OU,OU=NWMS Users,DC=internal,DC=contoso,DC=com"

#Space it out for the User
sleep 1
Write-Host "Creating User..."
sleep 1

#If Re-Hire
if ($HireStatus -like 'R'){
    #Splat data for rehire
    $OldUser = @{ 
            # Commented out section not needed, another app syncs this data to the user AD profile.
            #'SamAccountName' = $Sam
            #'Name' = $FullName
            #'GivenName' = $FirstName
            #'Surname' = $LastName
            #'UserPrincipalName' = $Sam+'@nwmotorsport.com'
            #'Department' = $Position[1]
            #'Title' = $Position[0]
            #'StreetAddress' = $Location[0]
            #'City' = $Location[1]
            #'POBox' = $Location[2]
            #'Country' = 'US'
            #'Company' = 'Northwest Motorsport'
            'AccountPassword' = $PasswordSecure
            'ChangePasswordAtLogon' = $True
            'Path' = $OUPath
            'Enabled' = $True
    }
    Write-Output $OldUser
    #Attempt to get user from AD
    $Users = @()
    Try {
        $Users = Get-ADUser $Sam -ErrorAction Stop
        Write-Host "Success! Found: $($Users.Name)"
        if ($(Read-Host('Procceed with this user? Y/N')) -match 'y'){
            Set-ADUser -SamAccountName $Sam @OldUser -Verbose
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

#If New Hire
if ($HireStatus -like 'N'){
    #Splat data for new user
    $NewUser = @{ 
            # Commented out section not needed, another app syncs this data to the user AD profile.
            'SamAccountName' = $Sam
            'Name' = $FullName
            'GivenName' = $FirstName
            'Surname' = $LastName
            'UserPrincipalName' = $Sam+'@nwmotorsport.com'
            #'Department' = $Position[1]
            #'Title' = $Position[0]
            #'StreetAddress' = $Location[0]
            #'City' = $Location[1]
            #'POBox' = $Location[2]
            #'Country' = 'US'
            #'Company' = 'Northwest Motorsport'
            'AccountPassword' = $PasswordSecure
            'ChangePasswordAtLogon' = $True
            'Path' = $OUPath
            'Enabled' = $True
    }
    Write-Output $NewUser
    #Create User
    New-ADUser @NewUser -Verbose
}

#Skip if custom Groups defined
if ($PositionNumber -notmatch "skip"){
    #Add to Groups
    Add-ADGroupMember -Identity $Position[2] -Members $Sam -Verbose
    Add-ADGroupMember -Identity $($Location[0]+' '+$Position[3]) -Members $Sam -Verbose
}

#Directory Update script
If($(Read-Host('Run Directory Update? Y/N')) -match 'y'){
    invoke-item "\\share\public\Directory Maintainence\SMTP Batch Update.vbs"
    Write-Host "Proceed after directory update"
}

Pause

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
$Script = $Script.Replace('$ID',"$($ID)")
$Script = $Script.Replace('$Sam',"$($Sam)")
$Script = $Script.Replace('$Email',"$($Sam+'@northwestmotorsport.com')")
$Script = $Script.Replace('$PASSWORD2',"$($Password2)")
$Script = $Script.Replace('$PASSWORD3',"$($Password3)")
#Cleaned up mobile number
$Mobile2 = $Mobile.Replace("-","")
$Mobile2 = $Mobile2.Replace(" ","")
$Mobile2 = $Mobile2.Replace(")","")
$Mobile2 = $Mobile2.Replace("(","")
$Script = $Script.Replace('$Mobile',"$($Mobile2)")

#Export script
$Path = "\\internal.contoso.com\resources\scripts\Onboarding\Users\$($FullName).side"
Write-Host "Selenium script exported to $Path"
$Script | Out-File -FilePath $Path -Force -Verbose

#Open browser to use Selenium
Start-Process -FilePath 'C:\Program Files\Mozilla Firefox\firefox.exe'

#Open documentation sheet
Invoke-Item "$env:UserProfile\Contoso\IT Department - Documents\Employee Management\Employee Onboarding Worksheet.dotx"

#Data to copy into sheet
Write-Host "
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
"
#Remind to attach O365 Licensce
if ($Position[0] -match "Sales Rep"){
    Write-Host "Add Exchange License Business`n"
}
elseif ($Position[1] -notmatch "Lot Technician"){
    Write-Host "Add Exchange License E3`n"
}
#Remind user to attach Groups
if ($PositionNumber -match "skip"){
    Write-Host '!!!!!!!!!!!!!!!!!'
    Write-Host 'Need to manually add users AD Groups'
}

#Stop and wait for user
Pause
stop-transcript

If($(Read-Host('Run AD Sync Update? Y/N')) -match 'y'){
    ."\\Contoso\public\Directory Maintainence\AD External Data Sync\ContosoAPICall.ps1"
    Write-Host "Proceed after AD Sync update"
}
