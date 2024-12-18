Set-StrictMode -Version Latest

if (!$IsWindows)
{
    throw "Only supported on Windows."
}

[Hashtable] $WSLEnvArgs = @{
    Name = 'WSLENV'
    Delimiter = ':'
}

<#
.SYNOPSIS
Gets the contents of the `WSLENV` environment variable.

.INPUTS
None

.OUTPUTS
System.String[]
    When at most one target is specified and AsObject is false.

PSCustomObject
    When AsObject is true or more than one target is specified.
#>
function Get-WslEnvironment
{
    [CmdletBinding()]
    param
    (
        # Specifies one or more target scopes to get.  Valid values are Process (the default), User, or Machine.
        [Parameter()]
        [Alias('Scope')]
        [EnvironmentVariableTarget[]] $Target,

        # Specify to return all -Target types.
        [Parameter()]
        [switch] $List,

        # Specifies that this cmdlet return the environment variable as an object with Name, Target, and Value, instead of just the value.
        [Parameter()]
        [switch] $AsObject
    )

    Get-DelimitedEnvironmentVariable @WSLEnvArgs -Target:$Target -List:$List -AsObject:$AsObject -SplitOptions ([StringSplitOptions]::RemoveEmptyEntries)
}

<#
.SYNOPSIS
Sets the `WSLENV` variable to the specified values.

.INPUTS
None

.OUTPUTS
None
#>
function Set-WSLEnvironment
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The values to set the variable to.
        [Parameter(Position = 0)]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process
    )

    Set-DelimitedEnvironmentVariable @WSLEnvArgs -Target:$Target -Value:($Value | Where-Object Length)
}

<#
.SYNOPSIS
Adds the specified entries to the `WSLENV` variable.

.INPUTS
None

.OUTPUTS
None
#>
function Add-WSLEnvironment
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The values to append (or prepend) to the variable.
        [Parameter(Position = 0, Mandatory)]
        [Alias("Values")]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # If true, the specified values will be prepended to the environment variable instead of appended.
        [Parameter()]
        [switch] $Prepend,

        # If true, the specified values will always be added.
        # If false, the specified values will only be added if they are not already in the environment variable.
        # Defaults to true for Prepend, false for Append.
        [Parameter()]
        [switch] $Force = $Prepend
    )

    Add-ValueToDelimitedEnvironmentVariable @WSLEnvArgs -Target:$Target -Value:$Value -Prepend:$Prepend -Force:$Force -SplitOptions ([StringSplitOptions]::RemoveEmptyEntries) -Confirm:$false
}

<#
.SYNOPSIS
Removes the specified entries from the `WSLENV` environment variable.

.INPUTS
None

.OUTPUTS
None
#>
function Remove-WSLEnvironment
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The entry or entries to remove from the variable.
        [Parameter(Position = 0, Mandatory)]
        [Alias("Values")]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # Forces the cmdlet to remove values without confirmation.
        [Parameter()]
        [switch] $Force
    )

    # Ditch trailing slash
    [string[]] $ToRemove = $Value

    foreach ($TargetItem in $Target)
    {
        [string[]] $OldValues = @(Get-WSLEnvironment -Target:$TargetItem -AsObject:$false)
        [string[]] $FinalValues = $OldValues | Where-Object {
            $item = $_
            return ($ToRemove -notcontains $item)
        }

        [string[]] $RemovedValues = $OldValues | Where-Object { $FinalValues -notcontains $_ }

        Write-Debug "${TargetItem}: Value=($Value) Removed=$($RemovedValues) Final=$($FinalValues)"
        if (!$RemovedValues)
        {
            # Nothing to remove
            continue
        }

        [string] $msg = "Remove (${RemovedValues}) from 'WSLENV' at ${TargetItem} to get (${FinalValues})"

        if (!$PSCmdlet.ShouldProcess($msg, "Remove-WSLEnvironment"))
        {
            continue
        }
        if (!$Force -and ($TargetItem -ne [EnvironmentVariableTarget]::Process) -and !$PSCmdlet.ShouldContinue($msg, 'Confirm'))
        {
            continue
        }

        # We've already confirmed, no need to confirm again
        Set-WSLEnvironment -Value:$FinalValues -Target:$TargetItem -Confirm:$false
    }
}

