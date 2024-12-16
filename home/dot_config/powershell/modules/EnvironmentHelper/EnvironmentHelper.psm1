using namespace System
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.IO

param()

Set-StrictMode -Version Latest

$Script:IsWindows = $PSVersionTable.PSVersion.Major -lt 6 -or $IsWindows

[EnvironmentVariableTarget[]] $AllTargets = [Enum]::GetValues([EnvironmentVariableTarget]) | Sort-Object -Descending

function GetUnexpandedEnvironmentVariable([string] $Name, [EnvironmentVariableTarget] $Target)
{
    if (!$IsWindows)
    {
        # PowerShell does not support environment variable targets other than Process outside Windows.
        return
    }

    switch ($Target)
    {
        ([EnvironmentVariableTarget]::Process)
        {
            # Process variables aren't expanded...
            [Environment]::GetEnvironmentVariable($Name, $Target)
        }
        ([EnvironmentVariableTarget]::User)
        {
            (Get-Item -LiteralPath 'HKCU:\Environment').GetValue($Name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        ([EnvironmentVariableTarget]::Machine)
        {
            (Get-Item -LiteralPath 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment').GetValue($Name, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        }
        default
        {
            Write-Error -Category InvalidArgument "Invalid target: $Target"
        }
    }
}

<#
.SYNOPSIS
    Gets the value for the specified environment variable for each scope.
.NOTES
    If more than one Target is specified, objects will be returned instead of values as if -AsObject were specified.
#>
function Get-EnvironmentVariable
{
    [CmdletBinding(DefaultParameterSetName = 'Target', SupportsShouldProcess = $false)]
    [OutputType([string])]
    [OutputType([PSCustomObject])]
    param
    (
        # The name of the environment variable.
        # If none is specified, all variables will be returned.
        [Parameter(Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $Name,

        # Specifies one or more target scopes to get.  Valid values are Process (the default), User, or Machine.
        [Parameter(ParameterSetName = 'Target')]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # Gets all values for the environment variable listed in precedence order.
        # By default, Get-EnvironmentVariable gets only the Process target's values.
        [Parameter(ParameterSetName = 'List')]
        [switch] $List,

        # Specifies that this cmdlet return the environment variable as an object with Name, Target, and Value, instead of just the value.  Only applies if there is one Name and one Target.
        [Parameter()]
        [switch] $AsObject,

        # Specifies that this cmdlet return the raw, unexpanded environment variable value.
        # Only applies to Machine, User targets.
        [Parameter()]
        [switch] $Raw
    )

    begin
    {
        $Target = switch ($PSCmdlet.ParameterSetName)
        {
            'List' { if ($List) { $AllTargets } }
            'Target' { $Target }
            default { $Target }
        }

        $AsObject = $AsObject -or $List -or $Target.Length -gt 1
    }

    process
    {
        if ($Name)
        {
            return $Target | ForEach-Object {
                [EnvironmentVariableTarget] $currentTarget = $_
                $Name | ForEach-Object {
                    [string] $currentName = $_
                    $Value = if ($Raw)
                    {
                        if ($currentTarget -eq [EnvironmentVariableTarget]::Process)
                        {
                            Write-Error -Category InvalidOperation -Message "-Raw is not supported on process-level environment variables."
                            return
                        }
                        GetUnexpandedEnvironmentVariable -Name:$currentName -Target:$currentTarget
                    }
                    else
                    {
                        # Get the expanded value.
                        [Environment]::GetEnvironmentVariable($currentName, $currentTarget)
                    }

                    if ($null -eq $Value)
                    {
                        # TODO can't distinguish between "variable set but empty" and "variable not present".
                        return # you get nothing
                    }

                    if ($AsObject)
                    {
                        return [PSCustomObject]@{
                            Name = $currentName
                            Target = $currentTarget
                            Value = $Value
                        }
                    }
                    else
                    {
                        return $Value
                    }
                }
            }
        }

        # No name.  Return every variable at each target.
        # NOTE: this returns variables with null values.
        return $Target | ForEach-Object {
            [EnvironmentVariableTarget] $currentTarget = $_
            $vars = [Environment]::GetEnvironmentVariables($currentTarget)

            $vars.GetEnumerator() | ForEach-Object {
                # cdonnelly 2018-07-17: For consistency do not return nulls.
                return [PSCustomObject] @{
                    Name = $_.Name
                    Target = $currentTarget
                    Value = $_.Value
                }
            }
        } | Sort-Object Name, @{ Expression = 'Target'; Descending = $true }
    }
}


<#
.SYNOPSIS
    Looks for environment variables matching the specified names, and returns them with name, target, and value.
#>
function Find-EnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess = $false)]
    [SuppressMessageAttribute('PSReviewUnusedParameter', 'Name')]
    param
    (
        # The name of one or more environment variables. Wildcards are accepted.
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]] $Name,

        # Specifies one or more target scopes to get.  Valid values are Process (the default), User, or Machine.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process
    )

    process
    {
        return $Target | ForEach-Object {
            [EnvironmentVariableTarget] $currentTarget = $_

            return [Environment]::GetEnvironmentVariables($currentTarget).GetEnumerator() | Where-Object {
                $currentName = $_.Name
                $Name | Where-Object { $currentName -like $_ }
            } | ForEach-Object {
                return [PSCustomObject] @{
                    Name = $_.Name
                    Target = $currentTarget
                    Value = $_.Value
                }
            } | Sort-Object Name, @{ Expression = 'Target'; Descending = $true }
        }
    }
}

<#
.SYNOPSIS
    Sets the named environment variable to the specified values.
.NOTES
    Setting the value to null or empty string will result in the environment variable being removed.
#>
function Set-EnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the environment variable.
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The value to set the variable to.
        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process
    )

    process
    {
        # for pretty-printing
        [string] $msg = '{0} = {1}, target: {2}' -f `
        (ConvertTo-Json -Compress -InputObject $Name),
        (ConvertTo-Json -Compress -InputObject $Value),
        ($Target -join ', ')

        if (!$PSCmdlet.ShouldProcess($msg, 'Set Environment Variable'))
        {
            return
        }

        switch ($Target)
        {
            ([EnvironmentVariableTarget]::Process)
            {
                # Process: Just set it unconditionally; I don't think the slowness mentioned below applies.
                [Environment]::SetEnvironmentVariable($Name, $Value, $_)
            }

            default
            {
                # [Environment]::SetEnvironmentVariable for User can be slow, so check the value isn't the same first.
                # The worst part is, I can't figure out what it is that's listening on my home PC:
                #   - closed all Chrome/Electron apps
                #   - even closed ConEmu and used a plain PowerShell
                # Still takes ~20 seconds.
                #
                # TODO figure out a way to speed this up.
                # @see https://stackoverflow.com/questions/4825967/environment-setenvironmentvariable-takes-a-long-time-to-set-a-variable-at-user-o

                [string] $oldValue = Get-EnvironmentVariable -Target $_ -Name $Name -Raw
                if ($oldValue -cne $Value)
                {
                    Write-Debug "different! $(@{ Old = $oldValue; New = $Value } | ConvertTo-Json)"

                    # Strictly different
                    [Environment]::SetEnvironmentVariable($Name, $Value, $_)
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Removes the named environment variable to the specified values.
#>
function Remove-EnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the environment variable.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process
    )

    process
    {
        # for pretty-printing
        [string] $msg = '{0} at {1}' -f `
        (ConvertTo-Json -Compress -InputObject $Name),
        ($Target -join ', ')

        if (!$PSCmdlet.ShouldProcess($msg, "Remove Environment Variable"))
        {
            return
        }

        switch ($Target)
        {
            ([EnvironmentVariableTarget]::Process)
            {
                # Process: Just remove it unconditionally; I don't think the slowness mentioned below applies.
                [Environment]::SetEnvironmentVariable($Name, '', $_)
            }

            default
            {
                # [Environment]::SetEnvironmentVariable for User can be slow, so check the value isn't the same first.
                # The worst part is, I can't figure out what it is that's listening on my home PC:
                #   - closed all Chrome/Electron apps
                #   - even closed ConEmu and used a plain PowerShell
                # Still takes ~20 seconds.
                #
                # TODO figure out a way to speed this up.
                # @see https://stackoverflow.com/questions/4825967/environment-setenvironmentvariable-takes-a-long-time-to-set-a-variable-at-user-o

                if (Get-EnvironmentVariable -Target $_ -Name $Name -Raw)
                {
                    # Non-null/non-empty value.  Set empty.
                    [Environment]::SetEnvironmentVariable($Name, '', $_)
                }
            }
        }
    }
}

<#
.SYNOPSIS
    Gets the values for the named, delimited environment variable.
.NOTES
    If more than one Target is specified, objects will be returned instead of values as if -AsObject were specified.
#>
function Get-DelimitedEnvironmentVariable
{
    [CmdletBinding(DefaultParameterSetName = 'Target', SupportsShouldProcess = $false)]
    [OutputType([string[]])]
    [OutputType([PSCustomObject])]
    [SuppressMessageAttribute('PSReviewUnusedParameter', 'Delimiter')]
    [SuppressMessageAttribute('PSReviewUnusedParameter', 'SplitOptions')]
    param
    (
        # The name of the environment variable.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The delimiter separating values.
        [Parameter(Position = 1, Mandatory)]
        [Alias('Separator')]
        [ValidateNotNullOrEmpty()]
        [string] $Delimiter,

        # Specifies one or more target scopes to get.  Valid values are Process (the default), User, or Machine.
        [Parameter(ParameterSetName = 'Target')]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # Gets all values for the environment variable listed in precedence order.
        # By default, Get-DelimitedEnvironmentVariable gets only the Process target's values.
        [Parameter(ParameterSetName = 'List')]
        [switch] $List,

        # Specifies that this cmdlet return the environment variable as an object with Name, Target, and Value, instead of just the value.  This only works if specifying a single Target.
        [Parameter()]
        [switch] $AsObject,

        # The [StringSplitOptions] to use when splitting the value.
        [Parameter()]
        [StringSplitOptions] $SplitOptions = [StringSplitOptions]::None,

        # Specifies that this cmdlet return the raw, unexpanded environment variable value.
        [Parameter()]
        [switch] $Raw
    )

    begin
    {
        $Target = switch ($PSCmdlet.ParameterSetName)
        {
            'List' { if ($List) { $AllTargets } }
            'Target' { $Target }
            default { $Target }
        }

        $AsObject = $AsObject -or $List -or $Target.Length -gt 1
    }

    process
    {
        Get-EnvironmentVariable -Raw:$Raw -Name:$Name -Target:$Target -AsObject | ForEach-Object {
            $Values = $_.Value.Split($Delimiter, $SplitOptions)

            if ($AsObject)
            {
                return [PSCustomObject] @{
                    Name = $_.Name
                    Target = $_.Target
                    Value = $Values
                }
            }
            else
            {
                return $Values
            }
        }
    }
}

<#
.SYNOPSIS
    Sets the named, delimited environment variable to the specified values.
#>
function Set-DelimitedEnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the environment variable.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The delimiter separating values.
        [Parameter(Position = 1, Mandatory)]
        [Alias('Separator')]
        [ValidateNotNullOrEmpty()]
        [string] $Delimiter,

        # The sequence of values to set the variable to.
        [Parameter(Position = 2)]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process
    )

    [string] $sValue = [string]::Join($Delimiter, $Value)
    Set-EnvironmentVariable -Name:$Name -Target:$Target -Value:$sValue
}

<#
.SYNOPSIS
    Adds the specified values to the named, delimited environment variable.
#>
function Add-ValueToDelimitedEnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the environment variable.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The delimiter separating values.
        [Parameter(Position = 1, Mandatory)]
        [Alias('Separator')]
        [ValidateNotNullOrEmpty()]
        [string] $Delimiter,

        # The value or values to append (or prepend) to the variable.
        [Parameter(Position = 2, Mandatory)]
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
        [switch] $Force = $Prepend,

        # The [StringSplitOptions] to use when splitting the value.
        [Parameter()]
        [StringSplitOptions] $SplitOptions = [StringSplitOptions]::None
    )

    $ToAdd = $Value
    foreach ($TargetItem in $Target)
    {
        $Raw = $TargetItem -ne [EnvironmentVariableTarget]::Process # raw and process don't mix
        [string[]] $OldValues = @(Get-DelimitedEnvironmentVariable -Raw:$Raw -Name:$Name -Delimiter:$Delimiter -Target:$TargetItem -AsObject:$false -SplitOptions:$SplitOptions)

        # Resolve the new values.
        $NewValues = [HashSet[string]]::new($ToAdd)
        if (!$Force -and $OldValues)
        {
            # Not forced; only include values we don't have.
            # MSCRAP: Can't use Linq (it's only in PowerShell 3.0+)
            # Not forced; only include values we don't have.
            $NewValues.ExceptWith($OldValues)

            if ($NewValues.Count -eq 0)
            {
                Write-Debug "${Name}@${TargetItem}: nothing to add -- (${ToAdd}) already present"
                continue
            }
            else
            {
                Write-Debug "${Name}@${TargetItem}: will add (${NewValues}) -- ($($ToAdd -cne $NewValues)) already present"
            }
        }

        if ($Prepend)
        {
            $FinalValues = $NewValues + $OldValues
            $msg = "${Name}: $((emphasize $NewValues) + $OldValues -join $Delimiter)"
        }
        else
        {
            $FinalValues = $OldValues + $NewValues
            $msg = "${Name}: $($OldValues + (emphasize $NewValues) -join $Delimiter)"
        }

        if (!$PSCmdlet.ShouldProcess($msg, "Add-ValueToDelimitedEnvironmentVariable"))
        {
            continue
        }
        if (($TargetItem -ne [EnvironmentVariableTarget]::Process) -and !$PSCmdlet.ShouldContinue($msg, 'Confirm'))
        {
            continue
        }

        if ($OldValues.Length -gt $FinalValues.Length)
        {
            $msg = "Delimited variable is shrinking ($($OldValues.Length) => $($FinalValues.Length))"
            Write-Debug -Message $msg
            throw [System.InvalidOperationException]$msg
        }

        # We've already confirmed, no need to confirm again
        Set-DelimitedEnvironmentVariable -Name:$Name -Delimiter:$Delimiter -Value:$FinalValues -Target:$TargetItem -Confirm:$false
    }
}

<#
.SYNOPSIS
    Removes the specified values from the named, delimited environment variable.
#>
function Remove-ValueFromDelimitedEnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the environment variable.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The delimiter separating values.
        [Parameter(Position = 1, Mandatory)]
        [Alias('Separator')]
        [ValidateNotNullOrEmpty()]
        [string] $Delimiter,

        # The value or values to remove from the variable.
        [Parameter(Position = 2, Mandatory)]
        [Alias("Values")]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # Whether the comparison is case-sensitive.
        [Parameter()]
        [switch] $CaseSensitive,

        # Whether to remove all instances of each value.
        [Parameter()]
        [switch] $All,

        # The [StringSplitOptions] to use when splitting the value.
        [Parameter()]
        [StringSplitOptions] $SplitOptions = [StringSplitOptions]::None,

        # Forces the cmdlet to remove values without confirmation.
        [Parameter()]
        [switch] $Force
    )

    foreach ($TargetItem in $Target)
    {
        $Raw = $TargetItem -ne [EnvironmentVariableTarget]::Process # raw and process don't mix

        [string[]] $ToRemove = $Value
        [string[]] $OldValues = @(Get-DelimitedEnvironmentVariable -Raw:$Raw -Name:$Name -Delimiter:$Delimiter -Target:$TargetItem -AsObject:$false -SplitOptions:$SplitOptions)
        [string[]] $NewValues = $OldValues | Where-Object {
            $item = $_
            $remove = if ($CaseSensitive) { $ToRemove -ccontains $item } else { $ToRemove -icontains $item }
            if ($remove -and !$All)
            {
                # We are removing the values once only, remove this value from the removals
                $ToRemove = $ToRemove | Where-Object { $_ -cne $item }
            }

            return $remove
        }

        Write-Debug "${TargetItem}: Value=(${Value}) NewValues=(${NewValues}) All=${All}"
        if (!$NewValues) { continue }


        [string] $msg = "Remove (${Value}) from '${Name}' at ${TargetItem} to get (${NewValues})"

        if (!$PSCmdlet.ShouldProcess($msg, "Remove-ValueFromDelimitedEnvironmentVariable"))
        {
            continue
        }
        if (!$Force -and ($TargetItem -ne [EnvironmentVariableTarget]::Process) -and !$PSCmdlet.ShouldContinue($msg, 'Confirm'))
        {
            continue
        }

        # We've already confirmed, no need to confirm again
        Set-DelimitedEnvironmentVariable -Name:$Name -Delimiter:$Delimiter -Value:$FinalValues -Target:$TargetItem -Confirm:$false
    }
}

<#
.SYNOPSIS
Refreshes the contents of the named, delimited environment variable within the current process based on the contents of the User and Machine targets.
#>
function Update-DelimitedEnvironmentVariable
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    [OutputType([void])]
    param
    (
        # The name of the path environment variable.  E.g. PATH, PSModulePath.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The delimiter separating values.
        [Parameter(Position = 1, Mandatory)]
        [Alias('Separator')]
        [ValidateNotNullOrEmpty()]
        [string] $Delimiter,

        # Whether the comparison is case-sensitive.
        [Parameter()]
        [switch] $CaseSensitive,

        # The [StringSplitOptions] to use when splitting the value.
        [Parameter()]
        [StringSplitOptions] $SplitOptions = [StringSplitOptions]::None
    )

    [scriptblock] $Comparison = if ($CaseSensitive)
    {
        { $process -cnotcontains $_ }
    }
    else
    {
        { $process -inotcontains $_ }
    }

    [string[]] $machineAndUser = Get-DelimitedEnvironmentVariable -Raw -Name $Name -Delimiter $Delimiter -Target Machine, User -SplitOptions:$SplitOptions | Select-Object -ExpandProperty Value
    [string[]] $process = Get-DelimitedEnvironmentVariable -Name $Name -Delimiter $Delimiter -Target Process -SplitOptions:$SplitOptions # Raw and process don't mix

    if ($machineAndUser | Where-Object $Comparison)
    {
        # Entries are missing.  Rebuild the delimited variable to include special values first if needed.
        [string[]] $Special = @()
        Set-DelimitedEnvironmentVariable -Name $Name -Delimiter $Delimiter -Target Process -Value ($Special + $machineAndUser)
        Add-ValueToDelimitedEnvironmentVariable -Name $Name -Delimiter $Delimiter -Target Process -Value $Process -SplitOptions:$SplitOptions
    }
}

####################################################################################################################################
# Path
####################################################################################################################################

[string] $PathDelim = [Path]::PathSeparator
[StringComparer] $PathComparer = if ($IsWindows) { [StringComparer]::OrdinalIgnoreCase } else { [StringComparer]::Ordinal }

<#
.SYNOPSIS
    Gets the values for the named, path-oriented environment variable.
.NOTES
    If more than one Target is specified, objects will be returned instead of values as if -AsObject were specified.
#>
function Get-PathVariable
{
    [CmdletBinding(DefaultParameterSetName = 'Target', SupportsShouldProcess = $false)]
    param
    (
        # The name of the path environment variable.  E.g. PATH, PSModulePath.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Specifies one or more target scopes to get.  Valid values are Process (the default), User, or Machine.
        [Parameter(ParameterSetName = 'Target')]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # Gets all values for the environment variable listed in precedence order.
        # By default, Get-PathVariable gets only the Process target's values.
        [Parameter(ParameterSetName = 'List')]
        [switch] $List,

        # Specifies that this cmdlet return the environment variable as an object with Name, Target, and Value, instead of just the value.
        [Parameter()]
        [switch] $AsObject,

        # Specifies that this cmdlet return the raw, unexpanded environment variable value.
        [Parameter()]
        [switch] $Raw
    )

    begin
    {
        $Target = switch ($PSCmdlet.ParameterSetName)
        {
            'List' { if ($List) { $AllTargets } }
            'Target' { $Target }
            default { $Target }
        }

        $AsObject = $AsObject -or $List -or $Target.Length -gt 1
    }

    process
    {
        Get-DelimitedEnvironmentVariable -Raw:$Raw -Name:$Name -Target:$Target -Delimiter:$script:PathDelim -AsObject:$AsObject -SplitOptions ([StringSplitOptions]::RemoveEmptyEntries)
    }
}

<#
.SYNOPSIS
    Sets the named, path-oriented environment variable to the specified values.
#>
function Set-PathVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the path environment variable.  E.g. PATH, PSModulePath.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The paths to set the variable to.
        [Parameter(Position = 1)]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process
    )

    Set-DelimitedEnvironmentVariable -Name:$Name -Target:$Target -Value:($Value | Where-Object Length) -Delimiter:$script:PathDelim
}

function emphasize([object] $Object)
{
    begin
    {
        $NewText = Get-Command -ErrorAction Ignore -Name 'New-Text'
    }

    process
    {
        if ($NewText)
        {
            New-Text -Object $Object -BackgroundColor $Host.UI.RawUI.ForegroundColor -ForegroundColor $Host.UI.RawUI.BackgroundColor
        }
        else
        {
            $Object
        }
    }
}

<#
.SYNOPSIS
    Adds the specified paths to the named, path-oriented environment variable.
#>
function Add-PathVariable
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        # The name of the path environment variable.  E.g. PATH, PSModulePath.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The paths to append (or prepend) to the variable.
        [Parameter(Position = 1, Mandatory)]
        [Alias("Path")]
        [Alias("Paths")]
        [Alias("Values")]
        [string[]] $Value,

        # Specifies one or more target scopes to modify.  Valid values are Process (the default), User, or Machine. Use of User or Machine will cause the new value to persist.
        [Parameter()]
        [Alias('Scope')]
        [ValidateNotNullOrEmpty()]
        [EnvironmentVariableTarget[]] $Target = [EnvironmentVariableTarget]::Process,

        # If true, the specified paths will be prepended to the environment variable instead of appended.
        [Parameter()]
        [switch] $Prepend,

        # If true, the specified paths will always be added.
        # If false, the specified paths will only be added if they are not already in the environment variable.
        # Defaults to true for Prepend, false for Append.
        [Parameter()]
        [switch] $Force = $Prepend
    )

    # Ditch trailing slash
    [string[]] $ToAdd = ($Value | ForEach-Object { $_.TrimEnd([Path]::DirectorySeparatorChar) })

    foreach ($TargetItem in $Target)
    {
        # Get the original values
        $Raw = $TargetItem -ne [EnvironmentVariableTarget]::Process # raw and process don't mix
        [string[]] $OldValues = @(Get-PathVariable -Raw:$Raw -Name:$Name -Target:$TargetItem -AsObject:$false)

        # Resolve the new values.
        $NewValues = [HashSet[string]]::new($ToAdd, $PathComparer)
        if (!$Force -and $OldValues)
        {
            # Not forced; only include values we don't have.
            # Ditch trailing slashes for comparison only
            $NewValues.ExceptWith([string[]] ($OldValues | ForEach-Object { $_.TrimEnd([Path]::DirectorySeparatorChar) }))

            if ($NewValues.Count -eq 0)
            {
                Write-Debug "${Name}@${TargetItem}: nothing to add -- (${ToAdd}) already present"
                continue
            }
            else
            {
                Write-Debug "${Name}@${TargetItem}: will add (${NewValues}) -- ($($ToAdd -ine $NewValues)) already present"
            }
        }

        if ($Prepend)
        {
            $FinalValues = $NewValues + $OldValues
            $strValues = ((emphasize $NewValues) + $OldValues -join $PathDelim)
        }
        else
        {
            $FinalValues = $OldValues + $NewValues
            $strValues = ($OldValues + (emphasize $NewValues) -join $PathDelim)
        }

        $msg = "Name: ${Name}, Target: ${TargetItem}, value: ${strValues}"
        if (!$PSCmdlet.ShouldProcess($msg, "Add-PathVariable"))
        {
            continue
        }
        if (($TargetItem -ne [EnvironmentVariableTarget]::Process) -and !$PSCmdlet.ShouldContinue($msg, 'Confirm'))
        {
            continue
        }

        if ($OldValues.Length -gt $FinalValues.Length)
        {
            $msg = "Delimited variable is shrinking ($($OldValues.Length) => $($FinalValues.Length))"
            Write-Debug -Message $msg
            throw [System.InvalidOperationException]$msg
        }

        # We've already confirmed, no need to confirm again
        Set-PathVariable -Name:$Name -Value:$FinalValues -Target:$TargetItem -Confirm:$false
    }
}

<#
.SYNOPSIS
    Removes the specified paths from the named, path-oriented environment variable.
#>
function Remove-PathVariable
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([void])]
    param
    (
        # The name of the path environment variable.  E.g. PATH, PSModulePath.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The path or paths to remove from the variable.
        [Parameter(Position = 1, Mandatory)]
        [Alias("Path")]
        [Alias("Paths")]
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
    [string[]] $ToRemove = @($Value | ForEach-Object { $_.TrimEnd([Path]::DirectorySeparatorChar) })

    foreach ($TargetItem in $Target)
    {
        $Raw = $TargetItem -ne [EnvironmentVariableTarget]::Process # raw and process don't mix
        [string[]] $OldValues = @(Get-PathVariable -Raw:$Raw -Name:$Name -Target:$TargetItem -AsObject:$false)
        [string[]] $FinalValues = $OldValues | Where-Object {
            $item = $_.TrimEnd([Path]::DirectorySeparatorChar)
            return ($ToRemove -notcontains $item)
        }

        [string[]] $RemovedValues = $OldValues | Where-Object { $FinalValues -notcontains $_ }

        [string] $msg = "Name: ${Name}, Target: ${TargetItem}, Removed: (${RemovedValues}), Value: (${FinalValues})"
        if (!$RemovedValues)
        {
            # Nothing to remove
            Write-Debug "Nothing to remove: ${msg}"
            continue
        }


        if (!$PSCmdlet.ShouldProcess($msg, "Remove-PathVariable"))
        {
            continue
        }
        if (!$Force -and ($TargetItem -ne [EnvironmentVariableTarget]::Process) -and !$PSCmdlet.ShouldContinue($msg, 'Confirm'))
        {
            continue
        }

        # We've already confirmed, no need to confirm again
        Set-PathVariable -Name:$Name -Value:$FinalValues -Target:$TargetItem -Confirm:$false
    }
}

<#
.SYNOPSIS
Refreshes the contents of the named, path-oriented environment variable within the current process based on the contents of the User and Machine targets.
#>
function Update-PathVariable
{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "Medium")]
    [OutputType([void])]
    param
    (
        # The name of the path environment variable.  E.g. PATH, PSModulePath.
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    [string[]] $machineAndUser = Get-PathVariable -Raw -Name $Name -Target Machine, User | Select-Object -ExpandProperty Value
    [string[]] $process = Get-PathVariable -Name $Name -Target Process # Raw and process don't mix

    if ($machineAndUser | Where-Object { $process -notcontains $_ })
    {
        # Entries are missing.  Rebuild the PATH variable as:
        #   - PATH only: powershell path
        #   - Machine
        #   - User
        #   - rest of Process
        [string[]] $Special = switch ($Name)
        {
            'PATH' { $Env:PSHOME }
        }

        Set-PathVariable -Name $Name -Target Process -Value ($Special + $machineAndUser)
        Add-PathVariable -Name $Name -Target Process -Value $Process
    }
}

function Find-ExistingPaths
{
    [CmdletBinding(SupportsShouldProcess = $false)]
    [OutputType([string])]
    param
    (
        [Parameter(Mandatory, ValueFromPipeline = $true, Position = 0)]
        [Alias("Path")]
        [PSObject[]] $Paths
    )

    begin
    {
        Write-Verbose "Find-ExistingPaths BEGIN   $($Paths.Length) $Paths"
        if (!$Paths) { return }
    }
    process
    {
        Write-Verbose "Find-ExistingPaths PROCESS $($Paths.Length) $Paths"

        $Paths |
            Where-Object { Write-Verbose "Find-ExistingPaths`t=> test $_"; $_.Length -and (Test-Path -PathType Container $_) } |
            ForEach-Object { Write-Verbose "Find-ExistingPaths`t=> get-item $_"; (Get-Item $_).FullName }
    }
    end
    {
        Write-Verbose "Find-ExistingPaths END     $($Paths.Length) $Paths"
    }
}

#
# Aliases
#

if ($IsWindows)
{
    # Only create the alias in Windows.
    New-Alias -Name env -Value Get-EnvironmentVariable
}

#
# Tab Completion
#

if ($PSVersionTable.PSVersion.Major -ge 6)
{
    Microsoft.PowerShell.Core\Register-ArgumentCompleter `
        -CommandName `
        Get-EnvironmentVariable, Find-EnvironmentVariable, Set-EnvironmentVariable, Remove-EnvironmentVariable, `
        Get-DelimitedEnvironmentVariable, Set-DelimitedEnvironmentVariable, Add-ValueToDelimitedEnvironmentVariable, Remove-ValueFromDelimitedEnvironmentVariable `
        -ParameterName 'Name' `
        -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

        Find-EnvironmentVariable -Name "${wordToComplete}*" | Select-Object -ExpandProperty Name
        @()
    }

    Microsoft.PowerShell.Core\Register-ArgumentCompleter `
        -CommandName Get-PathVariable, Set-PathVariable, Add-PathVariable, Remove-PathVariable `
        -ParameterName 'Name' `
        -ScriptBlock {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        Write-Verbose "argcomplete $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters"

        # Prefer the variable PATH to all others on completion
        $pattern = "${wordToComplete}*"
        if ('PATH' -ilike $pattern)
        {
            Write-Output 'PATH'
        }

        Find-EnvironmentVariable -Name $pattern |
            Where-Object { $_.Name -ilike '*PATH*' } |
            Select-Object -ExpandProperty Name
        @()
    }
}

