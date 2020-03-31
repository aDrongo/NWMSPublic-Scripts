class GUI{
    [string]$FilePath
    $XAML
    $Reader
    $Window

    GUI(){
    }

    GUI($FilePath){
        $this.LoadFilePath($FilePath)
        $this.CreateWindow()
        $this.ReadXAML()
        $this.CreateVariables()
    }

    LoadFilePath($FilePath){
        $this.FilePath = ".\LapsGUI\LapsGUI\MainWindow.xaml"
    }

    CreateWindow(){
        $this.XAML = Get-Content $this.FilePath -Raw
        [xml]$this.XAML = $this.XAML -replace 'mc:Ignorable="d"', '' -replace "x:N", 'N' -replace '^<Win.*', '<Window'
    }

    ReadXAML(){
        $this.Reader = (New-Object System.Xml.XmlNodeReader $this.XAML)
        try {
            $this.Window = [Windows.Markup.XamlReader]::Load($this.Reader)
        } catch {
            Write-Warning $_.Exception
            throw
        }
    }
    CreateVariables(){
        # Create variables based on form control names.
        # Variable will be named as 'var_<control name>'
        $this.XAML.SelectNodes("//*[@Name]") | ForEach-Object {
            #"trying item $($_.Name)"
            try {
                Set-Variable -Scope Global -Name "var_$($_.Name)" -Value $this.window.FindName($_.Name) -ErrorAction Stop
            } catch {
                throw
            }
        }
    }

    [object] static GetVariables(){
        return @(Get-Variable var_*)
    }
}
