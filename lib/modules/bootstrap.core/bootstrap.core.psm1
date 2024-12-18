using namespace System
using namespace System.Collections.Generic
using namespace System.IO

<#
.SYNOPSIS
Core bootstrap functionality.

.NOTES
We override ErrorActionPreference to default to Stop.
#>
param()

Set-StrictMode -Version Latest

# Make a backup of variable names/values and restore on module removal.
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

# Now override.
$global:ErrorActionPreference = 'Stop'