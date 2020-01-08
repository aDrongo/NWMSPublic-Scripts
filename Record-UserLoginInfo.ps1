#Gets User Login Details and records to Computer Object
#region begin logging
Class Logging {
    [ValidatePattern('^[\w\-. ]+$')][string]$Name
    [string]$LocalPath
    [string]$Time

    #Constructor with default values
    Logging(){
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.LocalPath = "$env:APPDATA\Logs\"
        $this.Name = "$($this.Time).log"
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    #TimeStamp Method
    static [String] GetTimeStamp(){
        Return $(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)
    }

    #Log message with default INFO level
    Log([string]$Message){
        $this.Log($Message,2)
    }

    #Log message with log level threshold check
    Log([string]$Message,[logginglevel]$Level){
        $Message = [logging]::GetTimeStamp() + " - $Level - " + $Message
        Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
    }
}

#Logging levels
Enum LoggingLevel
   {
      DEBUG = 1
      INFO = 2
      WARNING = 3
      ERROR = 4
      CRITICAL = 5
   }

$logger = [logging]::new()
#endregion

#region begin main
$CompName = $env:COMPUTERNAME
$UserName = $env:UserName

Try{
    $Computer = Get-ADComputer -Identity $env:COMPUTERNAME
    $logger.Log($Computer)
    $Computer | Set-ADComputer -Description $env:UserName
    $logger.Log("Setting Description to $env:UserName")
}
Catch{
    $logger.Log($Error[0],4)
    Exit 2
}
Try {
    $TV = (Get-itemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer\Version9\").ClientID
    $TV_Found = $True
    $Logger.Log("TV Found")
}
Catch { $logger.Log($Error[0],4) }
if($TV_Found){
    Try {
        Set-ADObject -Identity $Computer.ObjectGUID.Guid -replace @{extensionAttribute3=$TV}
        $Logger.Log("Setting TV: $TV")
    }
    Catch { $logger.Log($Error[0],4) }
}
Try{
    $IP = $(Get-NetIPAddress -AddressFamily IPv4).IPAddress | where-object {$_ -match "10.4.*"}
    $IP_Found = $True
    $Logger.Log("IP Found: $IP")
}
Catch { $logger.Log($Error[0],4) }
if($IP_Found){
    Try{
        $IP -match '\d+\.\d+\.\d+'
        $IP = $matches[0]
        $Subnet = Get-Content "\\internal.northwestmotorsportinc.com\resources\scripts\subnets.json" | ConvertFrom-Json
        $Location = $Subnet.$($IP)
        Set-ADObject -Identity $Computer.ObjectGUID.Guid -replace @{extensionAttribute2=$Location}
        $Logger.Log("Setting Location to $Location")
    }
    Catch { $logger.Log($Error[0],4) }
}
Try{
    $Serial = (get-wmiobject win32_bios serialnumber).SerialNumber
    Set-ADObject -Identity $Computer.ObjectGUID.Guid -replace @{extensionAttribute5=$Serial}
    $Logger.Log("Setting Serial to $Serial")
    }
Catch { $logger.Log($Error[0],4) }
#endregion

Exit 0