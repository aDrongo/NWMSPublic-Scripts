Configuration DeployFiles {  
	  
	  param( 
	    [Parameter(Mandatory=$true)] 
	    [String[]]$Servers, 
	    [Parameter(Mandatory=$true)] 
	    [String]$SourceFile, 
	    [Parameter(Mandatory=$true)] 
	    [String]$DestinationFile
	  ) 
	
	  Node $Servers
	  {  
	    File CopyHostFile
	    { 
	        Ensure = "Present" 
	        Type = "File" 
	        SourcePath = $SourceFile
	        DestinationPath = $DestinationFile
	    } 
	  } 
	} 


#Get-DSCResource File -syntax 	

#Create MOF File
DeployFiles -Server lab01.internal.contoso.com -SourceFile "\\internal.contoso.com\Software\Test.txt" -DestinationFile "C:\Test.txt" -OutputPath C:\DSC

#Push Configuration
Start-DscConfiguration -Wait -verbose -Path "C:\DSC" -Force

