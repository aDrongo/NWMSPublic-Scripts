#Task
class Task {
    [string]$Title
    [string]$Message
    [System.Array]$Days = @()
    [System.Array]$DaysofMonth = @()
    [boolean]$Sent

    #Constructor with specified details
    Task([string]$Title,[string]$Message,$Days){
        $this.Initialize($Title,$Message,$Days)
    }

    #Constructor overload with Days of Month
    Task([string]$Title,[string]$Message,$Days,$DaysofMonth){
        [ValidateScript({$_ -in (1 .. 31)})]$DaysofMonth
        $this.Initialize($Title,$Message,$Days)
        foreach ($Day in $DaysofMonth){
            $this.DaysofMonth += $Day
        }
    }

    #Method used by Constructor
    hidden Initialize($Title,$Message,$Days){
        $this.Title = $Title
        $this.Message = ([string]$Message).Insert(0,"#category Task`n")
        if ($Message -notmatch '#due'){
            $this.Message = $this.Message.Insert(0,"#due in 8 hours`n")
        }
        if ($Days -eq 'All' -or $Days -eq 7){
            $this.Days += [System.DayOfWeek].GetEnumNames()
        }
        else{
            foreach ($Day in $Days){
                $this.Days += [System.DayOfWeek]$Day
            }
        }
    }

    #Method to Send Ticket.
    hidden TestorSendTicket($Test){
        Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailPlainServer
        $Date = Get-Date
        if ($Date.DayOfWeek -in $this.Days){
            #If Days of Month specified, check if Day matches
            if ($this.DaysOfMonth.Count -gt 0){
                if ($Date.Date.Day -in $this.DaysofMonth){
                    if (!$Test){
                        Send-MailServer -body $this.Message -to 'help@contoso.on.spiceworks.com'  -subject $this.Title
                        #Write-Host "Sent Message $($this.Title)"
                    }
                    $this.Sent = $True
                }
                else{
                    $this.Sent = $False
                }
            }
            else{
                #Import-Module \\internal.contoso.com\resources\scripts\Modules\Private\Send-MailPlainServer
                if (!$Test){
                    Send-MailServer -body $this.Message -to 'help@contoso.on.spiceworks.com'  -subject $this.Title
                    #Write-Host "Sent Message $($this.Title)"
                }
                $this.Sent = $True
            }
        }
        else{
            $this.Sent = $False
        }
    }

    SendTicket(){
        $Result = $this.TestorSendTicket($False)
    }

    TestTicket(){
        $Result = $this.TestorSendTicket($True)
    }
}

class Tasks{
    $Files
    $Tasks
    $ErrorLog


    Tasks(){
        $this.Initialize()
        $this.GetFiles()
        $this.LoadFiles()
    }

    Tasks($Path){
        $this.Initialize()
        $this.GetFiles($Path)
        $this.LoadFiles()
    }

    hidden Initialize(){
        $this.ErrorLog = @()
        $this.Tasks = [System.Collections.ArrayList]@()
    }

    hidden GetFiles(){
        $this.Files = Get-ChildItem -LiteralPath '\\internal.contoso.com\resources\scripts\Tasks\Files'
    }


    hidden GetFiles($Path){
        $this.Files = Get-ChildItem -LiteralPath $Path
    }

    hidden LoadFiles(){
        Foreach ($File in $this.Files){
            Try{
                $Content = Get-Content $File.FullName | ConvertFrom-Json
                }
            Catch{
                $this.ErrorLog($Error[0])
                Continue
            }
            foreach ($Task in $Content){
                if($Task.DaysOfMonth){
                    $this.Tasks.add([Task]::new($Task.Title,$Task.Message,$Task.Days,$Task.DaysofMonth))
                }
                else{
                    $this.Tasks.add([Task]::new($Task.Title,$Task.Message,$Task.Days))
                }
            }
        }
    }

    [string] SendTickets(){
        $String = ""
        Foreach ($Task in $this.Tasks){
            $Task.SendTicket()
            $String += "----------------------------- `n"
            $String += $($Task | FL | Out-String).trim() + "`n"
            $String += "----------------------------- `n"
        }
        return $String
    }

    [string] TestTickets(){
        $String = ""
        Foreach ($Task in $this.Tasks){
            $Task.TestTicket()
            $String += "----------------------------- `n"
            $String += $($Task | FL | Out-String).trim() + "`n"
            $String += "----------------------------- `n"
        }
        return $String
    }
}
