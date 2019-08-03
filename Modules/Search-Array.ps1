#Search Function for Arrays
Function Search-Array($Array){
    #Get first column name
    $Name = $($Array | GM -MemberType NoteProperty)[0].Name
    #If Array not numbered then add numbers and list
    if ($($($Array.$($Name))[0]).StartsWith("1") -eq $False){
        $i = 0
        foreach ($item in $Array){
            $i++
            $item.$($Name) = "$i. "+$item.$($Name)
            Write-Host "$($item.$($Name))"
        }
    }
    #if already numbered then just list.
    else {
        foreach ($item in $Array){
            Write-Host "$($item.$($Name))"
        }
    }
    #Loop untill valid result
    :loop while ($true){
        #Get User input
        $Number = $(Read-Host('Enter No. or "search"'))
        #check user input
        if ($Number -notmatch "^[0-9]*$" -AND $Number -notmatch "search" -AND $Number -notmatch "skip"){
            Write-Host "Invalid input"
        }
        #If valid move to next
        else {
            break loop
        }
    }
    #If Search selected
    if ($Number -match 'search'){
        #loop untill valid result
        :loop while ($true){
            #search result dictionary
            $Result = [ordered]@{}
            $Search = Read-Host ('Type search term')
            #loop through array, add any matching
            foreach ($item in $Array){
                if ($item[0] -like "*$Search*"){
                    $Result += $item
                }
            }
            #If Results contains values then present to user and get them to select or search again
            if($Result.Count -ge 1){
                Write-Host $($Result | Out-String)
                $Number = $(Read-Host('Enter selection or "search" again'))
                #if user input valid then break loop
                $Max = $Array.Count
                if ($Number -in 0..$($Max)){
                    break loop
                }
                else {Write-Host 'Out of bounds'}
            }
            #Else let user know no results and get to search again
            else{
                Write-Host "Couldn't find anything matching $Search"
                if($(Read-Host('Search again Y/N?')) -match 'n'){
                $Number = 'skip'
                break loop}
            }
        }
    }
    #Return selected array
    if ($Number -ne 'skip'){
        $Number = [int]$Number
        return $Array[$($Number-1)]
    }
}