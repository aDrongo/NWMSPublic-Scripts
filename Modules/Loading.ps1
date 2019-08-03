#Why? Because.
$Speed = 3

$Line1 = '     __        ______        ___       _______   __  .__   __.   ______          '
$Line2 = '    |  |      /  __  \      /   \     |       \ |  | |  \ |  |  /  ____|         '
$Line3 = '    |  |     |  |  |  |    /  ^  \    |  .--.  ||  | |   \|  | |  |  __          '
$Line4 = '    |  |     |  |  |  |   /  /_\  \   |  |  |  ||  | |  . "  | |  | |_ |         '
$Line5 = '    |  "----.|  "--"  |  /  _____  \  |  "--"  ||  | |  |\   | |  |__| |         '
$Line6 = '    |_______| \______/  /__/     \__\ |_______/ |__| |__| \__|  \______|         '

$StaticArray = @()
$StaticArray += $Line1
$StaticArray += $Line2
$StaticArray += $Line3
$StaticArray += $Line4
$StaticArray += $Line5
$StaticArray += $Line6

$Length = $StaticArray[0].Length

$i = 0
While ($True){
    $i++
    $Speed = 4 * $i
    $DynamicArray = @()
    foreach ($Line in $StaticArray){
    $Add = $Line.Substring($($Length-$Speed),$($Speed))
    $Line = $Line.remove($($Length-$Speed),$($Speed))
    $Line = $Line.insert(0,"$Add")
    $DynamicArray +=$Line
    }
    cls
    write-output $DynamicArray
    Start-Sleep -MilliSeconds 500
    if ($i -eq 20){$i = 0}
}

