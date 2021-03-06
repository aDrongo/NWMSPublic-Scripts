Using Module \\internal.contoso.com\resources\scripts\Modules\Logging
. \\internal.contoso.com\resources\scripts\Tasks\Class.ps1

$Logger = [logging]::new()
$Logger.SetPublishPath('\\internal.contoso.com\resources\scripts\Logs\DailyTasks')
$Logger.Log('Starting Script')

$Tasks = [Tasks]::new()

foreach ($Task in $Tasks.Tasks){
    $Task.SendTicket()
    $Logger.Log($Task)
}

$Logger.Log('Finished Script')
$Logger.PublishLog()
