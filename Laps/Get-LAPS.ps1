. .\LapsClass.ps1
Import-Module ActiveDirectory

:loop while ($true){
    cls
    $Computer = [Laps]::new()
    $Computer | FT | Out-String
    Set-Clipboard $Computer.password -Verbose
    pause
}
