#Generate simple Password
. \\internal.northwestmotorsportinc.com\resources\scripts\Modules\Get-RandomCharacters.ps1
function GeneratePassword(){
    $Password = Get-RandomCharacters -length 6 -characters 'abcdefghikmnoprtuvwxyz'
    $Password += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNPRTUVWXYZ'
    $Password += Get-RandomCharacters -length 1 -characters '1234567890'
    Return $Password
}