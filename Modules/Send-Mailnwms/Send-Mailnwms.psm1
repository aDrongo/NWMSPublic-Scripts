Function Send-MailContoso {
    [CmdletBinding()]
    param(
    [Parameter(Mandatory=$true, Position=0)]$body,
    [Parameter(Position=1)]$to = "it@contoso.com",
    [Parameter(Position=2)]$subject = "Script Executed",
    [Parameter(Position=3,mandatory=$false)][System.IO.FileInfo]$attachment
    )

    $username = "outgoing@contoso.com"
    $pass = "" | ConvertTo-SecureString -AsPlainText -Force
    $creds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username,$pass
    $mail = @{
               to = $to.Split(',')
               from = "outgoing@contoso.com"
               subject = $subject
               body = $body
               dno = "OnFailure"
               smtpserver = "smtp.office365.com"
               port = "587"
               credential = $creds
               BodyAsHtml = $true
               UseSsl = $true
    }
    if($attachment){
        Send-MailMessage @mail -Attachments $attachment
    }
    else{
        Send-MailMessage @mail
    }
}

Export-ModuleMember -Function Send-MailContoso
