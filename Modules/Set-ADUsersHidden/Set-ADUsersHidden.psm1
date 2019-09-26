<#
.SYNOPSIS
    Sets AD objects to hidden from address lists, can unhide
.DESCRIPTION
    Parameters
    If unhide
        foreach user
            set to unhide
    else
        foreach user
            try to add hide as true
            catch to replace hide as true
.Parameter Users
    AD User Objects to affect
.Parameter Unhide
    To unhide users, boolean value, default = $False
.NOTES
        Author     : Benjamin Gardner bgardner160@gmail.com
#>


Function Set-ADUsersHidden {
    [CmdletBinding(SupportsShouldProcess)]
    param(
    [Parameter(ValueFromPipeline)][Microsoft.ActiveDirectory.Management.ADUser]$User,
    [Parameter()][boolean]$Unhide = $False
    )
process {
    if($Unhide){
            Write-Verbose "$User.Name replacing False to HideFromAddressLists"
            Set-ADuser -Identity $User.ObjectGUID.Guid -Replace @{msExchHideFromAddressLists="FALSE"} -Verbose
        }
    else {
            Try {
                Write-Verbose "$User.Name adding True to HideFromAddressLists"
                Set-ADuser -Identity $User.ObjectGUID.Guid -Add @{msExchHideFromAddressLists="TRUE"} -Verbose
            }
            Catch{
                Write-Verbose "$User.Name replacing True to HideFromAddressLists"
                Set-ADuser -Identity $User.ObjectGUID.Guid -Replace @{msExchHideFromAddressLists="TRUE"} -Verbose
            }
        }
    }
}

Export-ModuleMember -Function Set-ADUsersHidden