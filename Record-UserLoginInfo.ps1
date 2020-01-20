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

$Logger = [logging]::new()

Function Get-Sha256Hash
{
    Param (
    [string] $InputString
    )
    
    $hasher = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256')
    $hash = $hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($InputString))
    $hashString = [System.BitConverter]::ToString($hash)

    return $hashString.Replace('-', '').ToLower()
}
#endregion

$Logger.Log("Starting Record-UserLoginInfo.ps1")

$Result = New-Object PSObject

#region begin main
#Ensure connectivity, this is an attempt to solve hanging issue.
Try{
    Sleep 1
    $Connected = Test-Path '\\internal.contoso.com\resources' -IsValid -ErrorAction Stop
    $Logger.log("Connected")
    }
Catch{
    $Logger.log($Error[0],4)
    Exit 1
}
if(!$Connected){
    $Logger.log("Not Connected",4)
    Exit 1
}

#Get Computer and User names
$CompName = $env:COMPUTERNAME
$UserName = $env:UserName

$Result | Add-Member -MemberType NoteProperty -Name 'ComputerName' -Value $CompName
$Result | Add-Member -MemberType NoteProperty -Name 'UserName' -Value $UserName

#Find TeamViewer Number
Try {
    $TV = (Get-itemProperty "HKLM:\SOFTWARE\WOW6432Node\TeamViewer\Version9\").ClientID
    $TV_Found = $True
    $Logger.Log("TV Found")
}
Catch { $logger.Log($Error[0],4) }
#Set TeamViewer Number to Computers Attribute
if($TV_Found){
    Try {
        $Result | Add-Member -MemberType NoteProperty -Name 'TeamViewer' -Value $TV
        $Logger.Log("Setting TV: $TV")
    }
    Catch { $logger.Log($Error[0],4) }
}
#Find Computers IP
Try{
    $IP = $(Get-NetIPAddress -AddressFamily IPv4).IPAddress | where-object {$_ -match "10.4.*"}
    $IP_Found = $True
    $Logger.Log("IP Found: $IP")
}
Catch { $logger.Log($Error[0],4) }
#Match IP to store location and record location to Computers Attribute
if($IP_Found){
    Try{
        $Result | Add-Member -MemberType NoteProperty -Name 'IP' -Value $IP
        $IP -match '\d+\.\d+\.\d+'
        $IP = $matches[0]
        $Subnet = Get-Content "\\internal.contoso.com\resources\scripts\subnets.json" | ConvertFrom-Json
        $Location = $Subnet.$($IP)
        $Result | Add-Member -MemberType NoteProperty -Name 'Location' -Value $Location
        $Logger.Log("Setting Location to $Location")
    }
    Catch { $logger.Log($Error[0],4) }
}
#Get Computers Serial and write to Computers Attribute
Try{
    $Serial = (get-wmiobject win32_bios serialnumber).SerialNumber
    $Result | Add-Member -MemberType NoteProperty -Name 'Serial' -Value $Serial
    $Logger.Log("Setting Serial to $Serial")
    }
Catch { $logger.Log($Error[0],4) }
#endregion


if($Result.ComputerName){
    #Make API call with data collected
    $UriBase = "https://Servervslibrenms.internal.contoso.com:5000/api/v1/modify/"
    $Uri = $UriBase + "computer=$($Result.ComputerName)"
    if($Result.UserName){
        $Uri = $Uri + "&description=$($Result.UserName)"
    }
    if($Result.Location){
        $Uri = $Uri + "&extensionAttribute2=$($Result.Location)"
    }
    if($Result.TeamViewer){
        $Uri = $Uri + "&extensionAttribute3=$($Result.TeamViewer)"
    }
    if($Result.Serial){
        $Uri = $Uri + "&extensionAttribute5=$($Result.Serial)"
    }

    #Sign API call with Key and Date
    $key = Get-Content .\key.pem
    $UriSign = ($Uri + "&Date=$(Get-Date -Format yyyyMMddHH)" + "&Key=$($key)").Replace($UriBase,'')
    $hash = Get-Sha256Hash -InputString $UriSign
    $Uri = $Uri + "&hash=$hash"

    $Return = (Invoke-WebRequest -Uri $Uri).Content | ConvertFrom-Json
    $Logger.Log(($Return | Out-String))
}
Else{
    $Logger.Log("No Computer Name",4)
}

Exit 0
