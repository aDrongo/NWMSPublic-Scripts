# create a DSC configuration to install WSUS and IIS and support remote management
Configuration WSUS {
    
    Import-DSCResource -ModuleName UpdateServicesDSC

    # define input parameter
    param(
        [string[]]$ComputerName = 'localhost'
    )

    # target machine(s) based on input param
    node $ComputerName {

        # Install WSUS Role and Services
        WindowsFeature WSUS {
            Ensure = "Present"
            Name = "UpdateServices"
        }
        WindowsFeature WSUSServices {
            Ensure = "Present"
            Name = "UpdateServices-Services"
            DependsOn = @('[WindowsFeature]WSUS')
        }
        WindowsFeature WSUSWID {
            Ensure = "Present"
            Name = "UpdateServices-WidDB"
            DependsOn = @('[WindowsFeature]WSUSServices')
        }
        UpdateServicesServer UpstreamServer {
            Ensure = "Present"
            UpStreamServerName = "nwmsvs400.internal.CONTOSO.com"
            UpStreamServerPort = "8531"
            UpStreamServerSSL = $True
            UpStreamServerReplica = $True
            DependsOn = @('[WindowsFeature]WSUSID')
        }

        # install the IIS server role
        WindowsFeature IIS {
            Ensure = "Present"
            Name = "Web-Server"
        }

        # install the IIS remote management service
        WindowsFeature IISManagement {
            Name = 'Web-Mgmt-Service'
            Ensure = 'Present'
            DependsOn = @('[WindowsFeature]IIS')
        }

        # enable IIS remote management
        Registry RemoteManagement {
            Key = 'HKLM:\SOFTWARE\Microsoft\WebManagement\Server'
            ValueName = 'EnableRemoteManagement'
            ValueType = 'Dword'
            ValueData = '1'
            DependsOn = @('[WindowsFeature]IIS','[WindowsFeature]IISManagement')
        }

        # configure remote management service
        Service WMSVC {
            Name = 'WMSVC'
            StartupType = 'Automatic'
            State = 'Running'
            DependsOn = '[Registry]RemoteManagement'
        }

    }

}

# create the configuration (.mof)
WSUS -ComputerName Computer1.internal.contoso.com  -OutputPath C:\DSC

# push the configuration to WEB-NUG
Start-DscConfiguration -Path c:\DSC -Wait -Verbose

#Get-DSCResource -Module UpdateServicesDSC -Name UpdateServicesServer | Select -ExpandProperty Properties