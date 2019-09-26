<#
.SYNOPSIS
    Gets all AD users with hide flag
.DESCRIPTION
    Parameters
    Get-AD Users
        filter by enabled 
        with all properties 
        in searchbase
        where hide is true
.Parameter SearchBase
    OU to search, default 'OU=Users,DC=internal,DC=contoso,DC=com'
.Parameter Enabled
    String! requires '', If AD users to search are enabled or not, default = '$true'
.NOTES
        Author     : Benjamin Gardner bgardner160@gmail.com
#>


Function Get-ADUsersHidden {
    [CmdletBinding(SupportsShouldProcess)]
    param(
    [Parameter()][string]$SearchBase = 'OU=Users,DC=internal,DC=contoso,DC=com',
    [Parameter()][string][ValidateSet('$true','$false')]$Enabled = '$true'
    )

    $Users = Get-AdUser -Filter "enabled -eq $Enabled" -Properties * -SearchBase $SearchBase | Where-object {$_.msExchHideFromAddressLists -eq 'TRUE'}

    Return $Users
}

Export-ModuleMember -Function Get-ADUsersHidden