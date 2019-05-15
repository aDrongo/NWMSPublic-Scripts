# create a DSC configuration to install WSUS and IIS and support remote management
Configuration DSC-VMHost {
   
    # define input parameter
    param(
        [string[]]$ComputerName = 'localhost'
    )

    Import-DscResource -Module xHyper-V
    Import-DscResource -Module PSDesiredStateConfiguration

    # target machine(s) based on input param
    node $ComputerName {

        # Install WSUS Role and Services
        WindowsFeature HyperV {
            Ensure = "Present"
            Name = "Hyper-V"
        }

        WindowsFeature HyperVPowerShell
        {
            Ensure = 'Present'
            Name   = 'Hyper-V-PowerShell'
            Dependson = '[WindowsFeature]HyperV'
        }

        xVMHost VMHost {
            IsSingleInstance = 'Yes'
            EnableEnhancedSessionMode = $True
            VirtualHardDiskPath = 'C:\Hyper-V\VHDs\'
            VirtualMachinePath = 'C:\Hyper-V\VMs\'
            DependsOn = '[WindowsFeature]HyperVPowershell'
        }
        xVMSwitch ExternalSwitch {
            Name = 'External Switch'
            Type = 'External'
            NetAdapterName = 'Ethernet'
            Ensure = 'Present'
            DependsOn = '[xVMHost]VMHost'
        }
        xVHD VHD1 {
            Name = 'DomainController'
            Path = 'C:\Hyper-V\VHDs\'
            Generation = 'Vhdx'
            Type = 'Dynamic'
            MaximumSizeBytes = '53687091200'
            Ensure = 'Present'
            DependsOn = '[xVMHost]VMHost'
        }
        xVMHyperV VM1 {
            Name = 'Domain Controller'
            VhdPath = 'C:\Hyper-V\VHDs\DomainController.vhdx'
            SwitchName = 'External Switch'
            Generation = 2
            StartupMemory = 4284481536
            ProcessorCount = 2
            Ensure = 'Present'
            DependsOn = '[xVHD]VHD1'
        }
        xVHD VHD2 {
            Name = 'WSUSReplica'
            Path = 'C:\Hyper-V\VHDs\'
            Generation = 'Vhdx'
            Type = 'Dynamic'
            MaximumSizeBytes = '53687091200'
            Ensure = 'Present'
            DependsOn = '[xVMHost]VMHost'
        }
        xVMHyperV VM2 {
            Name = 'WSUS Replica'
            VhdPath = 'C:\Hyper-V\VHDs\WSUSReplica.vhdx'
            SwitchName = 'External Switch'
            Generation = 2
            StartupMemory = 4284481536
            ProcessorCount = 2
            Ensure = 'Present'
            DependsOn = '[xVHD]VHD1'
        }

    }

}

# create the configuration (.mof)
DSC-VMHost -ComputerName LAB01.internal.contoso.com  -OutputPath C:\DSC

# push the configuration to WEB-NUG
Start-DscConfiguration -Path c:\DSC -Wait -Verbose -Force

