#Create Functions for HTML formating
Function css-percentage($Integer){
    if ($Integer -lt 50){
        Write-Output '"good"'
    }
    if ($Integer -in 50 .. 74){
        Write-Output '"ok"'
    }
    if ($Integer -in 75 .. 89){
        Write-Output '"bad"'
    }
    if ($Integer -ge 90){
        Write-Output '"critical"'
    }
}

Function css-mb($Integer){
    if ($Integer -gt 2000 ){
        Write-Output '"good"'
    }
    if ($Integer -in 1000 .. 2000){
        Write-Output '"ok"'
    }
    if ($Integer -in 250 .. 1000){
        Write-Output '"bad"'
    }
    if ($Integer -lt 250){
        Write-Output '"critical"'
    }
}

Function css-disk($Integer){
    if ($Integer -gt 10000 ){
        Write-Output '"good"'
    }
    if ($Integer -in 5000 .. 10000){
        Write-Output '"ok"'
    }
    if ($Integer -in 2500 .. 5000){
        Write-Output '"bad"'
    }
    if ($Integer -in 0 .. 2500){
        Write-Output '"critical"'
    }
}

Function css-perc_rev($Integer){
    if ($Integer -in 50 .. 100){
        Write-Output '"good"'
    }
    if ($Integer -in 25 .. 50){
        Write-Output '"ok"'
    }
    if ($Integer -in 10 .. 25){
        Write-Output '"bad"'
    }
    if ($Integer -in 0 .. 10){
        Write-Output '"critical"'
    }
}
