#Source https://adamtheautomator.com/build-powershell-gui/

Add-Type -AssemblyName PresentationFramework

. .\LapsClass.ps1
. .\GuiClass.ps1

$Gui = [Gui]::new(".\MainWindow.xaml")

$var_btnQuery.Add_Click( {
   #clear the result box
   $var_txtResult.Text = ""
       if ($result = [Laps]::new($var_txtQuery.Text)) {
            $var_txtResult.Text = $result | FL | Out-String
       }
   })

$Null = $Gui.Window.ShowDialog()
