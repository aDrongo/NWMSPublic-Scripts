#Search Function for Dictionaries
Function Search-Dictionary($Dictionary) {
    #Write Dictionary for user to view
    Foreach ($Key in $Dictionary.Keys){
        Write-Host "$Key $($Dictionary[$Key])"
    }
    #Loop untill valid result
    :loop while ($true){
        #Get User input
        $Number = $(Read-Host('Enter No. or "search" or "skip"'))
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
            #Loop through Keys in dictionary, pair keys to values and evalute the values against search term, if match then store in Result dictionary
            foreach ($Key in $Dictionary.keys){
                $Value = $Dictionary.$($Key)
                if ($Value -like "*$Search*"){
                    $Result += @{"$Key" = $Dictionary.$($Key)}
                }
            }
            #If Results contains values then present to user and get them to select or search again
            if($Result.Count -ge 1){
                Write-Host $($Result | Out-String)
                $Number = $(Read-Host('Enter No. or "search"'))
                #if user input valid then break loop
                if ($Number -match "^[0-9]*$"){
                    break loop
                }
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
    return $Number
}