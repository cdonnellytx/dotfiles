using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest

#
#
#

<#
.SYNOPSIS
Returns whether the value is "truthy".
.NOTES
Differences between it and simply converting the object to a Boolean:

- String literal '0' is false
- String literal 'false' (case-insensitively) is false
#>

function Test-IsTruthy
{
    [OutputType([bool])]
    param([object] $Value)

    switch ($Value)
    {
        '0' { return $false }
        'false' { return $false }
        default { return !!$Value}
    }
}

#
# Make a backup of variable names/values and restore on module removal.
#
$backup = Get-Variable -Name '*Preference' -Scope 'Global' | Select-Object Name, Value
$ExecutionContext.SessionState.Module.OnRemove = {
    $backup | ForEach-Object {
        $var = Get-Variable -Name $_.Name
        if ($var -and $var.Value -ne $_.Value)
        {
            Write-Verbose "Restoring $($_.Name)"
            $var.Value = $_.Value
        }
    }
}

#
# Now override.
#
$global:errorActionPreference = 'Stop'
$global:InformationPreference = 'Continue'
if (Test-IsTruthy $Env:CHEZMOI_VERBOSE)
{
    $global:VerbosePreference = 'Continue'
}
