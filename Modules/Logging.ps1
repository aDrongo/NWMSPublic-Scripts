Class Logging {
    [ValidatePattern('^[\w\-. ]+$')][string]$Name
    [string]$LocalPath
    [string]$Time
    [LoggingLevel]$LoggingLevel

    Logging(){
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.LoggingLevel = "INFO"
        $this.LocalPath = "$env:APPDATA\Logs\"
        $this.Name = "$($this.Time).log"
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    static [String] GetTimeStamp(){
        Return $(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)
    }

    SetLevel([LoggingLevel]$Level){
        $this.LoggingLevel = $Level
    }


    Log([string]$Message){
        $this.Log($Message,2)
    }

    Log([string]$Message,[logginglevel]$Level){
        if($Level -ge $this.LoggingLevel){
            $Message = [logging]::GetTimeStamp() + " - $Level - " + $Message
            Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
        }
    }
}

Enum LoggingLevel
   {
      DEBUG = 1
      INFO = 2
      WARNING = 3
      ERROR = 4
      CRITICAL = 5
   }

#Example
#$Logger = [logging]::new()
#
#$Logger.log('Your log')
#$Logger.log($Error[0],4)
