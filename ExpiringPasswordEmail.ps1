#Create Logfile
$LogName = "$(Get-Date -Format yyyyMMddhhmm).log"
$LogPath = "\\internal.contoso.com\resources\scripts\Logs\ExpiringPasswordEmail"
New-Item -Path $LogPath -Name $LogName -ItemType "File" -Force
$Log = New-Object System.Collections.Generic.List[System.Object]

#Email template
$username = "email@contoso.com"
$pass = "password" | ConvertTo-SecureString -AsPlainText -Force
$creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username,$pass

#Get Date
$Date = Get-Date -Format G
#$Expired = Get-Date -date $(get-date).AddDays(-84) -Format G

$Users = @()
#Get Users in OUs
$Log.Add("Get-ADGroupMembers 'Marketing'`n")
Try{
    $Marketing = Get-ADGroupMember -Identity "Marketing" -ErrorAction Stop
    $Log.Add("Success`n")
}
Catch {
    $Log.Add("Failed`n$($Error[0])`n")
}
$Log.Add("Get-ADGroupMembers 'Internet Development'`n")
Try{
    $Development = Get-ADGroupMember -Identity "Internet Development" -ErrorAction Stop
    $Log.Add("Success`n")
}
Catch {
    $Log.Add("Failed`n$($Error[0])`n")
}
$Users = $Marketing+$Development


#$Users =  Get-ADGroupMember -identity 'Remote Desktop Users'
$hash = @()

Add-Content -Path "$LogPath\$LogName" -Value "$Log"
$Log = New-Object System.Collections.Generic.List[System.Object]
#Loop through Users
Foreach ($User in $Users){
    $Log.Add("Get-ADUser $($User.SamAccountName)`n")
    Try{
        $ADUser = Get-ADUser -identity $User.SamAccountName -Properties passwordlastset,passwordneverexpires,mail -ErrorAction Stop
        $Log.Add("Success`n")
    }
    Catch {
        $Log.Add("Failed`n$($Error[0])`n")
    }
    if ($ADUser.Mail -eq $Null){
        $ADuser.Mail = $ADUser.GivenName+"."+$ADUser.Surname+"@nwmotorsport.com"
        $Log.Add("Users Mail is Null`n")
    }
    #Check if password expires
    if ($ADUser.PasswordNeverExpires -eq $False){
        #Get when password last set
        $Diff = New-TimeSpan -start $ADUser.PasswordLastSet -end $Date
        $Remaining = 90-$($Diff.Days)
        $Expires = (Get-Date -Date(Get-Date).AddDays($Remaining) -DisplayHint Date | out-string).trim()
        $URL = "https://azkaban.internal.contoso.com/adfs/portal/updatepassword?username="+$ADUser.mail
        #if password is getting close to expiring, email user
        if ($Diff.Days -ge 83 -AND $Diff.Days -le 90){
            $emailed = "no"
            $to = $ADUser.mail
            $subject = "Your Windows password is expiring soon"
            $body = "<p>Your Windows password will expire on $Expires.<br>Please go to $URL to update your password.</p>"

            $mail = @{
               to = $to
               subject = $subject
               body = $body
               from = "it@contoso.com"
               dno = "OnFailure"
               smtpserver = "smtp.office365.com"
               port = "587"
               credential = $creds
            }

            Try{ 
                Send-MailMessage @mail -UseSsl -BodyAsHtml -ErrorAction Stop 
                #Write-Output "$to`n$body"
                $emailed = "yes"
                $Log.Add("Email Success`n")
            }
            Catch {
                $emailed = "Failed, $($Error[0])"
                $Log.Add("Email Failed`n")
            }
            #Collection report
            $properties = @{
                User = $ADUser.Name
                PasswordLastSet = $ADUser.PasswordLastSet
                Expires = $Expires
                Emailed = $emailed
            }
            $hash += New-Object PSObject -Property $properties

            
        }
        #if password expired, email user
        elseif ($Diff.Days -gt 90){
            $emailed = "no"
            $Expired = $($Diff.Days)-90
            $to = $ADUser.mail
            $subject = "Your Windows password has expired"
            $body = "<p>Your Windows password has expired, it is $Expired days overdue.<br>Please go to $URL to update your password.</p>"
            
            $mail = @{
               to = $to
               subject = $subject
               body = $body
               from = "it@contoso.com"
               dno = "OnFailure"
               smtpserver = "smtp.office365.com"
               port = "587"
               credential = $creds
            }
            Try{ 
                Send-MailMessage @mail -UseSsl -BodyAsHtml -ErrorAction Stop
                #Write-Output "$to`n$body"
                $emailed = "yes"
                $Log.Add("Email success`n")
            }
            Catch {
                $emailed = "Failed, $($Error[0])"
                $Log.Add("Email failed`n")
            }
            #Collection report
            $properties = @{
                User = $ADUser.Name
                PasswordLastSet = $ADUser.PasswordLastSet
                Expires = "Expired"
                Emailed = $emailed
            }
            $hash += New-Object PSObject -Property $properties
        }
        else {
            $Log.Add("No expiring passwords`n")
        }   
    }
    else {
        $Log.Add("Password set to never expire,$User.SamAccountName`n")
    }
    Add-Content -Path "$LogPath\$LogName" -Value "$Log"
    $Log = New-Object System.Collections.Generic.List[System.Object]
}

#Email report to IT
$to = "it@contoso.com"
$subject = "Password expiration report"
$body = "Data: $($hash | out-string)"

$mail = @{
    to = $to
    subject = $subject
    body = $body
    from = "it@contoso.com"
    dno = "OnFailure"
    smtpserver = "smtp.office365.com"
    port = "587"
    credential = $creds
}
Try{ 
    Send-MailMessage @mail -UseSsl
    $Log.Add("Email IT Success`n")
}
Catch {
    $Log.Add("Email IT Failed`n$($Error[0])`n")
}
Add-Content -Path "$LogPath\$LogName" -Value "$Log"