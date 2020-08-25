. \\internal.northwestmotorsportinc.com\resources\scripts\Modules\Invoke-AwsApiCall.ps1

function GetAWSKey(){
    return Get-Content "\\internal.northwestmotorsportinc.com\resources\scripts\Modules\Private\AWSKey\ActiveDirectoryPowershell.json" | Convertfrom-JSON
}

function GetDealerMeUsers(){
    $Disclude = @('Detail Technician', 'Service Technician','Tire Technician','Shop Foreman','Lot Technician')
    $AWSKey = GetAWSKey
    $Uribase = "https://api.contoso.com/user?active=1&limit=1000"
    $Users = ((Invoke-AwsApiCall -Uri $Uribase -ApiKey $AWSKey.apiKey -AccessKeyID $AWSKey.accessKeyID -SecretAccessKey $AWSKey.secretAccessKey).data | Where-Object {($_.businessPhone -or $_.phone -or $_.extension) -and ($_.title -notin $Disclude)})
    return $Users
}

function GetDealerMeLocations(){
    $AWSKey = GetAWSKey
    $Uribase = "https://api.contoso.com/location"
    $Locations =  (Invoke-AwsApiCall -Uri $Uribase -ApiKey $AWSKey.apiKey -AccessKeyID $AWSKey.accessKeyID -SecretAccessKey $AWSKey.secretAccessKey).data
    return ($Locations | Sort-Object SortLocation)
}

function GetDealerMeDepartments(){
    $AWSKey = GetAWSKey
    $Uribase = "https://api.contoso.com/department"
    $Departments = (Invoke-AwsApiCall -Uri $Uribase -ApiKey $AWSKey.apiKey -AccessKeyID $AWSKey.accessKeyID -SecretAccessKey $AWSKey.secretAccessKey).data
    return ($Departments | Sort-Object SortDepartment)
}

function FormatPhone($Phone){
    if ($Phone.Length -ge 1){
        return $Phone.Substring(2).Insert(0,"(").Insert(4,")").Insert(5," ").Insert(9,"-")
        }
}

function GetUserPhone($User){
    if ($User.department.id -in @(2,3,4,5,14)){
        if ($User.phone){
            return FormatPhone -Phone $User.phone
        }
        elseif ($User.businessPhone){
            return FormatPhone -Phone $User.businessPhone
        }
        else {
            return " "
        }
    }
    else {
        if ($User.businessPhone){
            return FormatPhone -Phone $User.businessPhone
        }
        
        elseif ($User.phone){
            return FormatPhone -Phone $User.phone
        }
        else {
            return " "
        }
    }
}

function GetDepartmentPhone($Department,$Location){
    if ($Department.id -eq '4'){
        return "$(FormatPhone -Phone $location.financePhone)"
    }
    elseif ($Department.id -eq '2'){
        return "$(FormatPhone -Phone $location.mobileSalesPhone)"
    }
    elseif ($Department.id -eq '6'){
        return "$(FormatPhone -Phone $location.servicePhone)"
    }
    elseif ($Department.id -eq '7'){
        return "$(FormatPhone -Phone $location.partsPhone)"
    }
    else {
        return " "
    }
}

function CheckUserInDepartmentLocation($User, $Department, $Location){
    return ($User.location.reynoldsAlias -eq $Location.reynoldsAlias -and $User.department.id -eq $Department.id)
}

function GenerateDivBox($Json){
$Header = $Json | GM -type NoteProperty | select -ExpandProperty Name
@"
    <div class="panel"><div class="content">
        <table>
            <tr><th colspan="3">$Header</th></tr>
            $(foreach ($Obj in $json.$($Header)){
                "<tr><td>$($Obj.Name)</td><td $(if (!$Obj.Phone){'colspan="2"'})>$($Obj.Title)</td>"
                if($Obj.Phone){"<td x-ms-format-detection=`"none`">$($Obj.Phone)</td>"}
                '</tr>'
            })
        </table>
    </div></div>
"@
}

function GenerateDivBoxesFromJson($path){
    $jsonObjects = Get-Content $path | ConvertFrom-Json
    $string = '<div class="box">'
    foreach ($obj in $jsonObjects){
        $string += GenerateDivBox($Obj)
    }
    return $string + '</div>'
}

function ConvertTime($time){
    [datetime]::parseexact($time, 'HH:mm', $null).ToString('htt').ToLower()
}

function GetCSS(){
return @"
body {
    max-width: 1400px;
    font-size: 16px;
    -webkit-print-color-adjust: exact !important;
    color-adjust: exact;
    word-wrap:break-word;
    margin: 0 auto;
}
table {
    border-collapse:collapse;
    font-size: 16px;
    width:100%;
    text-align:center;
    table-layout: fixed;
}
th, td {
    white-space:nowrap;
    overflow:hidden;
    vertical-align: middle;
    text-aling: middle;
}

th {
    background: #d3d3d3 !important;
}

tr:nth-child(even){
    background: #F0F0F0 !important;
}

h3 {
    margin: 8px 0;
    font-size: 12px;
}
.box {
    column-count: 2;
    column-gap: 0;
}
.panel {
    break-inside: avoid;
}
.content {
    padding: 0px;
    border-radius: 1px;
}
.header {
    width: 100%;
}
@media print {
    .location {
        page-break-inside: avoid;
    }
    h2 {
        margin: 12px 0;
    }
    body {
        width: 720px;
        font-size: 12px;
    }
    table {
        font-size: 10px;
    }
    footer {
        font-size: 8px;
  }
}
@media screen and (max-width: 850px) {
    .box {
        column-count: 1;
    }
    h2 {
        margin: 12px 0;
    }
}
@media screen and (max-width: 500px) {
    body {
        font-size: 10px;
    }
    table {
        font-size: 10px;
    }
    h2 {
        margin: 8px 0;
        font-size: 12px;
    }
    h3 {
        margin: 4px 0;
        font-size: 9px;
    }
}
"@
}


function CreatePhoneList($Users,$Locations,$Departments){
    $Days = @("Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday")
    [System.Collections.ArrayList]$Users = GetDealerMeUsers
    $Locations = GetDealerMeLocations
    $Departments = GetDealerMeDepartments
 
    $Output = @"
<html>
<head>
    <title>Contoso Directory</title>
<style>
    $(GetCSS)
</style>
</head>
<body>
$(foreach ($Location in $Locations){
    "<div class=`"location`">`n"
        "<div class=`"header`">"
            "<h2 style=`"text-align:center`">$($Location.name)</h2>`n"
            "<table><tr><h3 x-ms-format-detection=`"none`"><div style=`"display:flex`"><div style=`"width:33%;text-align: left;`">$($Location.address.street) $($Location.address.city) $($Location.address.state) $($Location.address.zip)</div><div style=`"width:33%;text-align: center;`">Phone: $(FormatPhone -Phone $Location.phone)</div><div style=`"width:33%;text-align: right;`">CCC: (833) 407-4152</div></div></h3></tr>`n"
                "<tr>"
                foreach ($Day in $Days){
                    "<th>$Day</th>"
                }
                "</tr>`n<tr>"
                foreach ($Day in $Days){
                    "<td>$(ConvertTime -Time ($Location.hours.$($Day).open))-$(ConvertTime -Time ($Location.hours.$($Day).close))</td>"
                }
                "</tr>"
            "</table>"
        "</div>`n"
        "<div class=`"box`">"
        foreach ($Department in $Departments){
            $found = $false
            for ($i = 0; $i -lt $Users.Count ; $i++){
                $User = $Users[[int]$i]
                if (CheckUserInDepartmentLocation -User $User -Department $Department -Location $Location){
                    $found = $i
                    break
                }
            }
            if($found){
                "<div class=`"panel`"><div class=`"content`"><table>`n"
                    "<tr><th style=`"width:30%`">$($Department.name)</th><th style=`"width:37%`"></th><th x-ms-format-detection=`"none`" style=`"width:25%`">$(GetDepartmentPhone -Department $Department -Location $Location)</th><th style=`"width:8%`"></th><tr>`n"
                    for ($i = $found; $i -lt $Users.Count ; $i++){
                        $User = $Users[[int]$i]
                        if (CheckUserInDepartmentLocation -User $User -Department $Department -Location $Location){
                            "<tr><td>$($User.fullName)</td><td>$($User.title)</td><td x-ms-format-detection=`"none`">$(GetUserPhone -User $User)</td><td>$($User.extension)</td></tr>`n"
                            $Users.Remove($User)
                            $i -= 1
                        }
                    }
                "</table></div></div>`n"
            }
        }
    "</div></div>`n"
})

<div class="location">
    <h2 style="text-align:center;">Additional Lines</h2>
    $(GenerateDivBoxesFromJson('\\internal.northwestmotorsportinc.com\resources\scripts\Reports\PhoneList\Additional.json'))
    <p><small>CONFIDENTIALITY NOTICE: This document contains confidential information belonging to Contoso for business purposes only. If you are not the intended recipient, you are hereby notified that any disclosure, copying, distribution or taking any action based on the contents of this document is strictly prohibited. The information is intended only for the use of the employees or entities of Contoso and if such information is used improperly by staff it may result in disciplinary action, up to and including termination. If you have received this document in error, please contact sender and delete all copies</small></p>
</div>
</body>
</html>
"@

return $Output
}

Start-Transcript
Write-Host "Creating Phone List..."

$Output = CreatePhoneList

$Output | Out-File -LiteralPath "\\contoso\Public\PhoneList\Directory.html" -Force -Verbose

Try{
    $AWSKey = GetAWSKey
    Write-S3Object -BucketName 'contosophonelist' -Content $([string]$Output) -Key "PhoneList.html" -Region us-west-2 -Force -SecretAccessKey $AWSKey.secretAccessKey -AccessKey $AWSKey.accessKeyID -Verbose
}
Catch [System.Management.Automation.CommandNotFoundException]{
    Write-Host "To upload to S3, please install AWSPowershell Module"
}
Catch {
    $Error[0]
}
Stop-Transcript
sleep 3