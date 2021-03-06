<# 
.SYNOPSIS
    Logging Module. Please use "Using Module [Module Path]" to also import enumerator as well.
.DESCRIPTION
    Logging Module, logs to AppData by default and can publish full Log or filtered report to another location(eg network drive).

    Constructor
        Use $SomeVariable = [logging]::new() to initialize with defaults

    ConstructorOverload
        Use $SomeVariable = [logging]::new($LocalPath,$Name) to initialize with different path and name

    Defaults
        LocalPath = "$env:APPDATA\Logs"
        Time = $(Get-Date -Format FileDateTime)
        Name = $($this.time).log
        LoggingLevel = INFO

    Methods
        SetLevel($Level) to set Default Logging Level filter(default is INFO), 1-5 or DEBUG, INFO, WARNING, ERROR, CRITICAL
            This allows you to change logging verbosity for entire script if you set levels throughout.
        SetPublishPath($Path) to set Publish Path
        CleanLocalLogs($Days) removes all logs at local path older than $days
        CleanPublishLogs($Days) removes all logs at publish path older than $days
        Log($Message). Logs message with INFO level.
        Log($Message,$Level), Logs message with specified Level.
        PublishLog(), Publishs full log content to PublishPath.
        GenerateReport($Level), Filters content for events at or above the defined level.
        PublishReport(), Publishs report log content to PublishPath.
            PublishReport($Level), Overload to Generate and Publish report.
        EmailReport($Email,$Subject), Sends Report to $Email with $Subject as Header if Report has any events.
            EmailReport($Level,$Email,$Subject) Overload to Generate Report as well.
    
    Notes
        Please use "Using Module [Module Path]" to import enumerator as well.

    Example Script
        #Note, this does require your to handle your errors.
        Using Module \\internal.contoso.com\scripts\Modules\Logging

        $Logger = [logging]::new()

        $CsvPath = \\somepath\somewhere.csv
        Try {
            $Csv = Import-Csv -Path $CsvPath
            $Logger.Log("Imported $CsvPath")
        }
        Catch {
            $Logger.Log("Failed to import: $($Error[0])",5)
            #Optional email alert
            $Logger.EmailReport(4,'it@contoso.com','Script XYZ Failure')
            Throw $Error[0]
        }
        ... more scripty stuff until finished then send log to network drive
        $Logger.Publish()
        $Logger.CleanLocalLogs(7)
    
    Example Log
        2020-01-02-16:40:03:4444 - CRITICAL - Failed to import: Could not find file '\\somepath\somewhere\list.csv'.

    What you need to do to use this module.
        1. Set your default publish location
        2. Create your own send-mail module or remove it.
        3. Catch your errors.
#>


Class Logging {
    [ValidatePattern('^[\w\-. ]+$')][string]$Name
    [string]$LocalPath
    [string]$PublishPath
    [string]$Time
    [LoggingLevel]$LoggingLevel
    [System.Collections.ArrayList]$Content
    [System.Collections.ArrayList]$Report

    Logging(){
        $this.Initialize()
        $this.LocalPath = "$env:APPDATA\Logs\"
        $this.Name = "$($this.Time).log"
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    Logging([string]$LocalPath,[string]$Name){
        if(!(Test-Path $LocalPath)){
            Throw "$LocalPath does not exist"
        }
        $this.Initialize()
        $this.LocalPath = $LocalPath
        $this.TransformPath()
        $this.Name = $Name
        New-Item -Path $this.LocalPath -Name $this.Name -ItemType "File" -Force
    }

    hidden Initialize(){
        $this.Time = $(Get-Date -Format FileDateTime)
        ###### Change this #########
        $this.PublishPath = "\\internal.contoso.com\whatever\Logs\General\"
        $this.LoggingLevel = "INFO"
        $this.Content = [System.Collections.ArrayList]@()
    }

    hidden TransformPath(){
        if($this.PublishPath[-1] -ne '\'){
            $this.PublishPath = $this.PublishPath + '\'
        }
        if($this.LocalPath[-1] -ne '\'){
            $this.LocalPath = $this.LocalPath + '\'
        }
    }

    static [String] GetTimeStamp(){
        Return $(Get-Date -Format yyyy-MM-dd-HH:mm:ss:ffff)
    }


    static [PSCustomObject] GetLevels(){
        Return ([System.Enum]::GetValues([LoggingLevel])) | Foreach-Object {[PSCustomObject]@{ValueName = $_; IntValue = [int]$_}}
    }

    SetLevel([LoggingLevel]$Level){
        $this.LoggingLevel = $Level
    }

    hidden CleanLogs([string]$Path,[int]$Days){
        $Logs = Get-ChildItem $Path | Where-Object {($_.Name -match ".log") -and ($_.CreationTime -le (Get-Date).AddSeconds(-$Days))}
        foreach ($Log in $Logs){
            Try{
                $Log | Remove-Item -Force
                $this.Log("Cleaned $($log.Name)")
                }
            Catch{
                $this.Log("$($Error[0])",4)
            }
        }
    }

    CleanLocalLogs([Int]$Days){
        $this.CleanLogs($this.LocalPath,$Days)
    }

    CleanPublishLogs([Int]$Days){
        $this.CleanLogs($this.PublishPath,$Days)
    }

    SetPublishPath([string]$PublishPath){
        if(!(Test-Path $PublishPath)){
            Throw "$PublishPath does not exist"
        }
        $this.PublishPath = $PublishPath
        $this.TransformPath()
    }

    Log([string]$Message){
        $this.Log($Message,2)
    }

    Log([string]$Message,[logginglevel]$Level){
        if($Level -ge $this.LoggingLevel){
            $Message = [logging]::GetTimeStamp() + " - $Level - " + $Message
            Add-Content -Path ($this.LocalPath + $this.Name) -Value $Message -Force
            $this.Content.Add($Message)
        }
    }

    PublishLog(){
        Try {
            New-Item -Path $this.PublishPath -Name $this.Name -ItemType "File" -Force
            Set-Content -Path ($this.LocalPath + $this.Name) -Value $this.Content -Force
        }
        Catch{
            $this.Log($Error[0],4)
        }
    }

    GenerateReport([LoggingLevel]$Level){
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

    PublishReport(){
        if($this.Report.Count -gt 0){
            Try {
                New-Item -Path $this.PublishPath -Name $this.Name -ItemType "File" -Force
                Set-Content -Path ($this.LocalPath + $this.Name) -Value $this.Report -Force
            }
            Catch{
                $this.Log($Error[0],4)
            }
        }
    }

    PublishReport([logginglevel]$Level){
        $this.GenerateReport($Level)
        $this.PublishReport()
    }

    EmailReport([string]$Email,[string]$Subject){
        if($this.Report.Count -gt 0){
            Try{
                ###### Change this #########
                Import-Module \\internal.contoso.com\CreateYourOwnSend-MailModule\Send-MailServer
                Send-MailServer -body $this.Report -to $Email -subject $Subject
            }
            Catch{
                $this.Log($Error[0],4)
            }
        }
    }

    EmailReport([LoggingLevel]$Level,[string]$Email,[string]$Subject){
        $this.GenerateReport($Level)
        $this.EmailReport($Email,$Subject)
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


Export-ModuleMember -Function *
