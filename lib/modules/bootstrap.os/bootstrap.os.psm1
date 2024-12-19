using namespace System.Management.Automation
using namespace System.Security.Principal

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Tests whether the current user is running as administrator.
#>
function Test-IsAdministrator
{
    [OutputType([bool])]
    param()

    return ([WindowsPrincipal] [WindowsIdentity]::GetCurrent()).IsInRole([WindowsBuiltInRole] "Administrator")
}

<#
.SYNOPSIS
Asserts whether the current user is running as administrator.
#>
function Assert-IsAdministrator
{
    [OutputType([void])]
    param
    (
        # Specifies the assertion message.
        [Parameter(Position = 0)]
        [string] $Message = 'This command'
    )

    if (!(Test-IsAdministrator))
    {
        $exception = ([ScriptRequiresException]::new("${Message} cannot be run because it requires running as Administrator.  The current PowerShell session is not running as Administrator. Start PowerShell by using the Run as Administrator option, and then try running the script again."))
        Write-Error -Category PermissionDenied -Exception:$exception -ErrorAction Stop
    }
}
