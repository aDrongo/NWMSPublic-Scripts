<# 
.SYNOPSIS
    Logging Module. Please use "Using Module [Module Path]" to also import enumerator as well.
.DESCRIPTION
    Logging Module, logs to AppData by default and can publish full Log or filtered report to another location(eg network drive).

    Constructor
        Use $SomeVariable = [logging]::new() to initialize

    ConstructorOverload
        Use $SomeVariable = [logging]::new($LocalPath,$Name) to initialize with different path and name

    Defaults
        LocalPath = "$env:APPDATA\Logs"
        Name = $($this.time).log

    Methods
        SetPublishPath() to set Publish Path
        SetLevel() to set Default Logging Level filter(default is INFO), 1-5 or DEBUG, INFO, WARNING, ERROR, CRITICAL
            This allows you to easily edit this one setting to change logging verbosity for entire script if you set levels throughout when logging.
        Log($Message). Logs message with INFO level.
        Log($Message,$Level), Logs message with specified Level
        PublishLog(), Publishs full log content to PublishPath
        PublishReport(), Publishs report log content to PublishPath
        GenerateReport($Level), Filters content for issues at or above the defined level.

    Optional
        Set your own Send-Mail settings if you want to use it.
        EmailReport($Email,$Subject), Sends Report to $Email with $Subject as Header.
    
    Notes
        Please use "Using Module [Module Path]" to import enumerator as well.

    Example Script
        #Note, this does require your to handle your errors.
        Using Module \\internal.contoso.com\scripts\Modules\Logging

        $Logger = [logging]::new()
        $Logger.SetPath("\\internal.contoso.com\resources\scripts\ServerReports\Logs\")

        $CsvPath = \\somepath\somewhere.csv
        Try {
            $Csv = import-csv -Path $CsvPath
            $Logger.Log("Imported $CsvPath")
        }
        Catch {
            $Logger.Log("Failed to import: $($Error[0])",5)
            Throw $Error[0]
        }
        ... more scripty stuff until finished then send report to network drive
        $Logger.Publish()

        #Optionally email for alert
        $Logger.GenerateReport(4)
        $Logger.EmailReport('it@contoso.com','Script XYZ Failure')
    
    Example Log
        2020-01-02-16:40:03:4444 - CRITICAL - Failed to import: Could not find file '\\somepath\somewhere\list.csv'.
#>


Class Logging {
    [ValidatePattern('^[\w\-. ]+$')][string]$Name
    [string]$LocalPath
    [string]$PublishPath
    [string]$Time
    [LoggingLevel]$LoggingLevel
    [System.Collections.ArrayList]$Content
    [System.Collections.ArrayList]$Report

    #Constructor with default values
    Logging(){
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.Name = "$($this.Time).log"
        $this.LocalPath = "$env:APPDATA\Logs\"
        $this.PublishPath = "\\internal.contoso.com\whatever\Logs\General\"
        $this.LoggingLevel = "INFO"
        $this.Content = [System.Collections.ArrayList]@()
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    #Constructor with Specified Values
    Logging([string]$LocalPath,[string]$Name){
        if(!(Test-Path $LocalPath)){
            Throw "$LocalPath does not exist"
        }
        $this.Time = $(Get-Date -Format FileDateTime)
        $this.Name = $Name
        $this.LocalPath = $LocalPath
        $this.PublishPath = "\\internal.contoso.com\whatever\Logs\General\"
        $this.LoggingLevel = "INFO"
        $this.Content = [System.Collections.ArrayList]@()
        $this.CheckPath()
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    #Change Publish Path
    SetPublishPath([string]$PublishPath){
        if(!(Test-Path $PublishPath)){
            Throw "$PublishPath does not exist"
        }
        $this.PublishPath = $PublishPath
        $this.CheckPath()
    }

    #Transforms paths if they are missing a trailing slash so we can add path and name easily. 
    hidden CheckPath(){
        if($this.PublishPath[-1] -ne '\'){
            $this.PublishPath = $this.PublishPath + '\'
        }
        if($this.LocalPath[-1] -ne '\'){
            $this.LocalPath = $this.LocalPath + '\'
        }
    }

    #Set logging level threshold
    SetLevel([LoggingLevel]$Level){
        $this.LoggingLevel = $Level
    }

    #List log levels for user
    static [PSCustomObject] GetLevels(){
        Return ([System.Enum]::GetValues([LoggingLevel])) | Foreach-Object {[PSCustomObject]@{ValueName = $_; IntValue = [int]$_}}
    }

    #Log message with default INFO level
    Log([string]$Message){
        #Check if Logging Level is Set to allow Info(2)
        if($this.LoggingLevel -le 2){
            $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - INFO - " + $Message
            Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
            $this.Content.Add($Message)
        }
    }

    #Log message with log level threshold check
    Log([string]$Message,[logginglevel]$Level){
        if($Level -ge $this.LoggingLevel){
            $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - $Level - " + $Message
            Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
            $this.Content.Add($Message)
        }
    }

    #Push log to PublishPath
    PublishLog(){
        Try {
            New-Item -Path $this.PublishPath -Name $this.Name -ItemType "File" -Force
            Set-Content -Path ($this.LocalPath + $this.Name) -Value $this.Content -Force
        }
        Catch{
            $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - Error - " + $Error[0]
            Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
        }
    }

    #Push Report to PublishPath
    PublishReport(){
        if($this.Report.Count -gt 0){
            Try {
                New-Item -Path $this.PublishPath -Name $this.Name -ItemType "File" -Force
                Set-Content -Path ($this.LocalPath + $this.Name) -Value $this.Report -Force
            }
            Catch{
                $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - Error - " + $Error[0]
                Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
            }
        }
    }

    #Generate Report of logs at or above defined level
    GenerateReport($Level){
        $Levels = [System.Enum]::GetValues([LoggingLevel]) -ge $Level
        $List = [System.Collections.ArrayList]@()
        foreach($Filter in $Levels){
            if($this.Content -match $Filter){
                Foreach($Line in $this.Content){
                    $Result = $Line | Select-String "- $Filter -" -CaseSensitive
                    if($Result){
                        $List.Add($Result)
                    }
                }
            }
        }
        $this.Report = [System.Collections.ArrayList]@($List | select-object -Unique)
    }

    #Send email of report, Configure your own mail module if you want to use
    EmailReport([string]$Email,[string]$Subject){
        if($this.Report.Count -gt 0){
            Try{
                Import-Module \\internal.contoso.com\CreateYourOwnSend-MailModule\Send-MailServer
                Send-MailServer -body $this.Report -to $Email -subject $Subject
            }
            Catch{
                $Message = "$(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)" + " - Error - " + $Error[0]
                Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
            }
        }
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


Export-ModuleMember -Function *
