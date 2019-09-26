<#
.SYNOPSIS
    ConvertTo-HTML doesn't handle strings so this extends that feature.
.DESCRIPTION
    Parameters
    If string
        process parameters and start html body
            loop through string converting to html
            add string to html body
        close html and return
    else
        use convertto-html
.Parameter Intake
    Object to proccess
.Parameter convertParams
    HTML parameters, must be in following format. 
    $convertParams = @{ 
    head = @"
    <style>
    Your styles here
    </style>
    "@
    }
.NOTES
        Author     : Benjamin Gardner bgardner160@gmail.com
#>


Function ConvertHtml{
    param(
    [Parameter(mandatory=$true, Position=0)]$intake,
    [Parameter(Position=1)]$convertParams
    )
    if($intake.GetType().Name -match "String"){  
        $intakeReturn = "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN'  'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'>
        <html xmlns='http://www.w3.org/1999/xhtml'>
        <head>
        $(if($convertParams){$($convertParams.Values)})
        </head><body>"
        foreach ($string in $intake){
            $intakeReturn = $intakeReturn + $string + "<br>" }
        $intakeReturn = $intakeReturn + "<br></body></html>"
        Return $intakeReturn 
    }
    else{
        Return $($intake | ConvertTo-Html @convertParams)
    }
}

Export-ModuleMember -Function ConvertHtml