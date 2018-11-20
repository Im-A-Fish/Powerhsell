# Powershell script to create  bulk user upload with a provided CSV file. 
# The OUs need to be existant prior to creation else the script will not create the objects 
# Will Membery
 
#Powershell v2.5, Finished Script
 
#Import the Active Directory Module 
Import-module activedirectory  

# Making the errors messages shut up. More on this, Line 80 + 81
$ErrorActionPreference = "SilentlyContinue"
 
#Import the list from the user, and add the headers
$File = "C:\Assign2\Users.csv"
$Users = Import-Csv -Path $File -Header Firstname , Lastname 

# Starting/Declaring the counting variables
$UserCount = 0
$UserGroup = 1

# Starting the "Bad users" List
$BadUsers = New-Object 'System.Collections.Generic.List[System.Object]'

# Starting users in Group 1
Write-Host "Now putting Users in Group " $UserGroup -ForegroundColor Magenta

foreach ($User in $Users)             
{   
    # Increment the UserCount variable, so the first user created is 1
    # The UserCount will correspont with the CSV index value
    $UserCount++ 

    # Sort the Firstname and Lastname
    $UserFirstname = $User.Firstname 
    $UserLastname = $User.Lastname  

    # Increment the OU Group variable, on counts of 50
    if ($UserCount -eq 51 -OR $UserCount -eq 101 -OR $UserCount -eq 151 -OR $UserCount -eq 201 -OR $UserCount -eq 251) {
      $UserGroup++
      Write-Host "Now putting Users in Group " $UserGroup -ForegroundColor Magenta
    }

    # Skip the user creation if either variable is empty
    if (!$UserFirstname -OR !$UserLastName) { 
        Write-Host "Invalid name detected, skipping entry number" $Usercount -ForegroundColor Red
        $BadUsers.Add($UserCount) # Keeping track of bad users
        Continue
    }

    # Various field and variable manipulation to slot into the new-aduser command
    $Name = $UserFirstname + " " + $UserLastname # Format "First Last"
    $UserFirstIntial = $UserFirstname.Substring(0,1).toLower() # First initial, in lowercase  
    $Displayname =  $UserFirstIntial + $User.Lastname.toLower() # Displayname, lowercase -- Format "flast"            
    $OU = "OU=Group" + $UserGroup + ",DC=will,DC=is,DC=cool" # Specifying the OU Group, with incremented goup number     
    $UPN = $Displayname + "@will.is.cool" # Creating the UPN -- format "flast@will.is.cool"
    
    # Creating the new directory and other variables for future use
    New-Item -ItemType Directory -Path "\\WMDC02\Users$\$Displayname" 
    $Domain = 'Will'
    $UsersAm = "$Domain\$Displayname"

    # Identifies what type of access we are defining 
    $FileSystemAccessRights = [System.Security.AccessControl.FileSystemRights]"FullControl" 
    
    # Defines how the security propagates to child objects by default 
    $InheritanceFlags = [System.Security.AccessControl.InheritanceFlags]::"ContainerInherit", "ObjectInherit" 
    
    # Specifies which access rights are inherited from the parent folder
    $PropagationFlags = [System.Security.AccessControl.PropagationFlags]::None 
    
    # Access rules to apply to the users folders
    $AccessControl =[System.Security.AccessControl.AccessControlType]::Allow  

    # New access rule to apply to users folfers 
    $NewAccessrule = New-Object System.Security.AccessControl.FileSystemAccessRule ($UsersAm, $FileSystemAccessRights, $InheritanceFlags, $PropagationFlags, $AccessControl)  
 
    # Set acl for each user folder
    # First, define the folder for each user 
    $userfolder = "\\WMDC02\Users$\$Displayname" 

    # This errors out, try/catch block didn't help, so I suppressed errors earlier
    $currentACL = Get-ACL -path $userfolder 
    
    # Add this access rule to the ACL 
    $currentACL.SetAccessRule($NewAccessrule) 

    # Write the changes to the user folder 
    Set-ACL -path $userfolder -AclObject $currentACL 

    # Set variable for homeDirectory (personal folder) and homeDrive (drive letter) 
    $HomeDirectory = "\\WMDC02\Users$\$Displayname" #This maps the folder for each user  

    # Set homeDrive for each user 
    $homeDrive = "U:" #This maps the homedirectory to drive letter U
      
    # Creation of the account with the requested formatting.
    New-ADUser `
        -Name "$Name" `
        -DisplayName "$Displayname" `
        -GivenName "$UserFirstname" `
        -Surname "$UserLastname" `
        -UserPrincipalName "$UPN" `
        -SamAccountName "$Displayname" `
        -HomeDirectory "$HomeDirectory" `
        -HomeDrive "$HomeDrive" `
        -Path "$OU" `
        -PasswordNotRequired $True `
        -ChangePasswordAtLogon $True `
        -PasswordNeverExpires $false `
        -Enabled $true

    Write-Host "User" $Displayname "created." -ForegroundColor Green    
}

# Turn bad user list into array, and count the amount of them
$BadUsers.ToArray() | Out-Null # Prevents outputting to console
$BadCount = 0

# Blank line after creation text
Write-Host "Invalid Entries - Missing first or last name:"

# Loop through the baduser group and output the errors again, after the script is over
foreach ($Item in $BadUsers) {
    Write-Host "Missing value on line" $Item ", entry skipped" -ForegroundColor Red
    $BadCount++
}

# Total created users is the total count minus the bad user count
$CreatedCount = $UserCount - $BadCount

# Final Output statements
Write-Host "`n"
Write-Host "Script Over!"
Write-Host "Total Users created:" $CreatedCount