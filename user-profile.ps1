
<#
.Synopsis
   Rough PS functions to create new user profiles with SSK
.DESCRIPTION
   Call the Create-NewProfile function directly to create a new profile
.EXAMPLE
   Create-NewProfile -Username 'testUser1' -Password 'testUser1' -SshKey ''
.NOTES
   Created by: Josh Rickard (@MS_dministrator) and Thom Schumacher (@driberif)
   Date: 24MAR2017
   Location: https://gist.github.com/crshnbrn66/7e81bf20408c05ddb2b4fdf4498477d8

   Contact: https://github.com/MSAdministrator
            MSAdministrator.com
            https://github.com/crshnbrn66
            powershellposse.com
#>


#Function to create the new local user first
function New-LocalUser
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string] $userName,
        # Param2 help description
        [string]
        $password
    )
    New-LocalUser -Name 'clovirsm' -NoPassword
    <#$system = [ADSI]"WinNT://$env:COMPUTERNAME";
    $user = $system.Create("user",$userName);
    $user.SetPassword($password);
    $user.SetInfo();

    $flag=$user.UserFlags.value -bor 0x10000;
    $user.put("userflags",$flag);
    $user.SetInfo();

    $group = [ADSI]("WinNT://$env:COMPUTERNAME/Users");
    $group.PSBase.Invoke("Add", $user.PSBase.Path);
    #>
}

#function to register a native method
function Register-NativeMethod
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$dll,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]
        $methodSignature
    )

    $script:nativeMethods += [PSCustomObject]@{ Dll = $dll; Signature = $methodSignature; }
}
function Get-Win32LastError
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param($typeName = 'LastError')
 if (-not ([System.Management.Automation.PSTypeName]$typeName).Type)
    {
    $lasterrorCode = $script:lasterror | ForEach-Object{
        '[DllImport("kernel32.dll", SetLastError = true)]
         public static extern uint GetLastError();'
    }
        Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
        public static class $typeName {
            $lasterrorCode
        }
"@
    }
}
#function to add native method
function Add-NativeMethods
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param($typeName = 'NativeMethods')

    $nativeMethodsCode = $script:nativeMethods | ForEach-Object { "
        [DllImport(`"$($_.Dll)`")]
        public static extern $($_.Signature);
    " }

    Add-Type @"
        using System;
        using System.Text;
        using System.Runtime.InteropServices;
        public static class $typeName {
            $nativeMethodsCode
        }
"@
}

#Main function to create the new user profile
function Create-NewProfile {

    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$UserName,

        # Param2 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=1)]
        [string]
        $Password,

         # Param3 help description
        [Parameter(Mandatory=$false,
                   ValueFromPipelineByPropertyName=$true,
                   Position=2)]
        [string]
        $SshKey
    )

    Write-Verbose "Creating local user $Username";

    try
    {
        New-LocalUser -username $UserName -password $Password;
    }
    catch
    {
        Write-Error $_.Exception.Message;
        break;
    }
    $methodName = 'UserEnvCP'
    $script:nativeMethods = @();

    if (-not ([System.Management.Automation.PSTypeName]$MethodName).Type)
    {
        Register-NativeMethod "userenv.dll" "int CreateProfile([MarshalAs(UnmanagedType.LPWStr)] string pszUserSid,`
         [MarshalAs(UnmanagedType.LPWStr)] string pszUserName,`
         [Out][MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszProfilePath, uint cchProfilePath)";

        Add-NativeMethods -typeName $MethodName;
    }

    $localUser = New-Object System.Security.Principal.NTAccount("$UserName");
    $userSID = $localUser.Translate([System.Security.Principal.SecurityIdentifier]);
    $sb = new-object System.Text.StringBuilder(260);
    $pathLen = $sb.Capacity;

    Write-Verbose "Creating user profile for $Username";

    try
    {
        [UserEnvCP]::CreateProfile($userSID.Value, $Username, $sb, $pathLen) | Out-Null;
    }
    catch
    {
        Write-Error $_.Exception.Message;
        break;
    }
    if( $SshKey  ){
        New-Item -ItemType directory -Path C:\Users\$UserName\.ssh
        "$SshKey" | Out-File -FilePath C:\Users\$UserName\.ssh\authorized_keys -Encoding ascii
        icacls C:\Users\$UserName\.ssh\authorized_keys /inheritance:r
        icacls C:\Users\$UserName\.ssh\authorized_keys /grant $UserName`:`(F`)
        icacls C:\Users\$UserName\.ssh\authorized_keys /grant BUILTIN\Administrators:`(F`)
        Add-LocalGroupMember -Member $UserName -Group "Administrators"
      }
     else{
        Add-LocalGroupMember -Member $UserName -Group "Remote Desktop Users"
     }

}

function New-ProfileFromSID {

    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$UserName,
        [string]$domain = 'PHCORP'
    )
    $methodname = 'UserEnvCP2'
    $script:nativeMethods = @();

    if (-not ([System.Management.Automation.PSTypeName]$methodname).Type)
    {
        Register-NativeMethod "userenv.dll" "int CreateProfile([MarshalAs(UnmanagedType.LPWStr)] string pszUserSid,`
         [MarshalAs(UnmanagedType.LPWStr)] string pszUserName,`
         [Out][MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszProfilePath, uint cchProfilePath)";

        Add-NativeMethods -typeName $methodname;
    }

    $sb = new-object System.Text.StringBuilder(260);
    $pathLen = $sb.Capacity;

    Write-Verbose "Creating user profile for $Username";
    #$SID= ((get-aduser -id $UserName -ErrorAction Stop).sid.value)
  if($domain)
   {
        $objUser = New-Object System.Security.Principal.NTAccount($domain, $UserName)
        $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        $SID = $strSID.Value
   }
   else
   {
       $objUser = New-Object System.Security.Principal.NTAccount($UserName)
       $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
       $SID = $strSID.Value
   }
    Write-Verbose "$UserName SID: $SID"
    try
    {
       $result = [UserEnvCP2]::CreateProfile($SID, $Username, $sb, $pathLen)
       if($result -eq '-2147024713')
       {
           $status = "$userName already exists"
           write-verbose "$username Creation Result: $result"
        }
        elseif($result -eq '-2147024809')
        {
            $staus = "$username Not Found"
            write-verbose "$username creation result: $result"
        }
       elseif($result -eq 0)
       {
           $status = "$username Profile has been created"
           write-verbose "$username Creation Result: $result"
       }
       else
       {
          $status = "$UserName unknown return result: $result"
       }
    }
    catch
    {
        Write-Error $_.Exception.Message;
        break;
    }
    $status
}
Function Remove-Profile {

    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$UserName,
        [string]$ProfilePath,
        [string]$domain = 'PHCORP'
    )
    $methodname = 'userenvDP'
    $script:nativeMethods = @();

    if (-not ([System.Management.Automation.PSTypeName]"$methodname.profile").Type)
    {
      add-type @"
using System.Runtime.InteropServices;

namespace $typename
{
    public static class UserEnv
    {
        [DllImport("userenv.dll", CharSet = CharSet.Unicode, ExactSpelling = false, SetLastError = true)]
        public static extern bool DeleteProfile(string sidString, string profilePath, string computerName);

        [DllImport("kernel32.dll")]
        public static extern uint GetLastError();
    }

    public static class Profile
    {
        public static uint Delete(string sidString)
        { //Profile path and computer name are optional
            if (!UserEnv.DeleteProfile(sidString, null, null))
            {
                return UserEnv.GetLastError();
            }

            return 0;
        }
    }
}
"@
    }

   #$SID= ((get-aduser -id $UserName -ErrorAction Stop).sid.value)
   if($domain)
   {
        $objUser = New-Object System.Security.Principal.NTAccount($domain, $UserName)
        $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
        $SID = $strSID.Value
   }
   else
   {
       $objUser = New-Object System.Security.Principal.NTAccount($UserName)
       $strSID = $objUser.Translate([System.Security.Principal.SecurityIdentifier])
       $SID = $strSID.Value
   }
    Write-Verbose "$UserName SID: $SID"
    try
    {
        #http://stackoverflow.com/questions/31949002/c-sharp-delete-user-profile
       $result = [userenvDP.Profile]::Delete($SID)
    }
    catch
    {
        Write-Error $_.Exception.Message;
        break;
    }
    $LastError
}
 

if ($args.Count -eq 2) {
Create-NewProfile -Username $args[0] -Password $args[1]
}
else{
echo $args[0]
echo $args[2]
echo "net user"
net user $args[0] /ADD
#Create-NewProfile -Username $args[0] -Password $args[1] -SshKey $args[2]
}
