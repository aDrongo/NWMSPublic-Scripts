function Get-AzureSkuCount {    #Need to install Install-Module -Name AzureAD
    Try{ Import-Module AzureAD -Force } Catch { Install-PackageProvider nuget -force; Install-Module AzureAD -Scope CurrentUser -Force -Confirm:$false -ErrorAction SilentlyContinue -AllowClobber }
    $password = "PASSWORD" | ConvertTo-SecureString -asPlainText -Force    $username = "USERNAME@CONTOSO.COM"
    $credential = New-Object System.Management.Automation.PSCredential($username,$password)

    

    Connect-AzureAD -Credential $credential | Out-Null

    $licenseMap = Get-AzureADSubscribedSku | Select ConsumedUnits,PrepaidUnits,ObjectId,SkuId,SkuPartNumber | where {$_.SkuPartNumber -match "O365_BUSINESS_ESSENTIALS|ENTERPRISEPACK"}
    Return $licenseMap
}