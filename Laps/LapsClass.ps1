class Laps {
    [string]$Computer
    [string]$Password

    Laps(){
        #Interactive
        $this.SetAttributes([Laps]::Select([Laps]::Search([Laps]::GetName())))
    }

    Laps($Name){
        #Non-Interactive
        $this.SetAttributes([Laps]::GetComputer($Name))
    }

    SetAttributes($Item){
        $this.Computer = $Item.Name
        $this.Password = $Item.'ms-Mcs-AdmPwd'
    }

    [object] static GetComputer($Name){
        return Get-ADComputer -Identity $Name -Properties ms-Mcs-AdmPwd | Select Name,ms-Mcs-AdmPwd
    }

    [string] static GetName(){
        return Read-Host "Enter Name"
    }

    [object] static Search($Name){
        return @(Get-ADComputer -Filter "Name -like `"*$Name*`"" -Properties ms-Mcs-AdmPwd | Select Name,ms-Mcs-AdmPwd)
    }

    [object] static Select($Options){
        if ($Options.Count -le 0){
            throw "No items found"
        }
        elseif ($Options.Count -eq 1){
            return $Options[0]
        }
        else{
            $Options = [Laps]::AddIndex($Options)
            $Select = -1
            Write-Host($Options | FT | Out-String)
            Do {
                $Select = [int](Read-Host "Please select an object")
            }Until($Select -in (0 .. $Options.Count))
            return $Options[$Select]
        }
    }

    [object] static hidden AddIndex($Options){
        $i = 0
        foreach ($Option in $Options){
            $Option | Add-Member -NotePropertyName Index -NotePropertyValue $i
            $i++
        }
        return $Options
    }

}
