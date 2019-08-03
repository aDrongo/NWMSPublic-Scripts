#Create word proccess
$Word = New-Object -ComObject Word.Application
$Word.Visible = $True
#Open word document
$myFile = "$env:UserProfile\Downloads\Employee Separation Worksheet.docx"
$Doc = $Word.Documents.Add($myFile)
#Get details
$Selection = $Word.Selection
#Set default details
$wdFindContinue = 1
$MatchCase = $False 
$MatchWholeWord = $true
$MatchWildcards = $False 
$MatchSoundsLike = $False 
$MatchAllWordForms = $False 
$Forward = $True 
$Wrap = $wdFindContinue 
$Format = $False 
$wdReplaceNone = 0 
$wdFindContinue = 1 
$ReplaceAll = 2

#Search and replace
Function WordReplace($FindText,$ReplaceWith,$Selection){
    $Selection.Find.Execute($FindText,$MatchCase,$MatchWholeWord,$MatchWildcards,$MatchSoundsLike,$MatchAllWordForms,$Forward,$Wrap,$Format,$ReplaceWith,$ReplaceAll)
}

#Save
$Doc.Save()
$Doc.Close()
$Word.Quit()