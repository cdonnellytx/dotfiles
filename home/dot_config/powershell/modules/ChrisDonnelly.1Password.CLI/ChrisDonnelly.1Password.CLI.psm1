#requires -Version 5.1

param()

Set-StrictMode -Version Latest

[string[]] $DefaultFlags = '--format=json', '--iso-timestamps'

filter Format-OPItem([string[]] $TypeNames = @())
{
    foreach ($TypeName in $TypeNames)
    {
        $_.PSObject.TypeNames.Insert(0, $TypeName)
    }

    return $_
}

function Format-DateDiff([System.DateTimeOffset] $value)
{
    $now = [System.DateTimeOffset]::UtcNow
    switch ($value)
    {
        { $now.Year -gt $_.Year + 1 } { return '{0} years ago' -f ($now.Year - $_.Year) }
        { $now.Year -eq $_.Year + 1 -and $now.Month -ge $_.Month } { return '1 year ago' }
        { $now.Year -eq $_.Year + 1 } { return '{0} months ago' -f (12 + $now.Month - $_.Month) }
        { $now.Month -gt $_.Month + 1 } { return '{0} months ago' -f ($now.Month - $_.Month) }
        { $now.Month -eq $_.Month + 1 -and $now.Day -ge $_.Day } { return '1 month ago' }
        default
        {
            $diff = $now - $_
            switch ($diff)
            {
                { $_ -lt 0 } { return $_.ToString('o') } # THE FUTURE
                { $_.Days -ge 14 } { return '{0:G0} weeks ago' -f ($_.Days / 7) }
                { $_.Days -ge 7 } { return '1 week ago' }
                { $_.Days -gt 1 } { return '{0} days ago' -f $_.Days }
                { $_.Days -eq 1 } { return '1 day ago' }
                { $_.Hours -gt 1 } { return '{0} hours ago' -f $_.Hours }
                { $_.Hours -eq 1 } { return '1 hour ago' }
                { $_.Minutes -gt 1 } { return '{0} minutes ago' -f $_.Minutes }
                { $_.Minutes -eq 1 } { return '1 minute ago' }
                { $_ -ge 0 } { return 'Just now' }
            }
        }
    }
}

function Get-1PasswordCommand
{

    if (!($opCommand = Get-Command -Type Application -Name 'op' -ErrorAction SilentlyContinue -ErrorVariable ev))
    {
        # NOTE: ev is of type System.Collections.ArrayList
        $PSCmdlet.ThrowTerminatingError($ev[0])
    }

    return $opCommand
}

<#
.SYNOPSIS
Invokes the 1Password CLI with the given arguments.

#>
function Invoke-1Password
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $Arguments
    )

    $opCommand = Get-1PasswordCommand

    $Help = $Arguments -contains '--help'

    if ($Help)
    {
        # LATER: pager
        & $opCommand $Arguments
        return
    }

    [string[]] $CommandNames = $Arguments | Where-Object { $_ -is [string] -and $_ -match '^[A-Z]+$' }
    if (!$CommandNames)
    {
        & $opCommand $Arguments
        return
    }

    if (!$PSCmdlet.ShouldProcess("Command: '$($CommandNames -join ' ')'", "Invoke 1Password CLI"))
    {
        return
    }

    # Assign the custom objects type names so we can make important ones format nicely by default.
    [string[]] $TypeNames = 0..($CommandNames.Length - 1) | ForEach-Object {
        'ChrisDonnelly.OnePassword.{0}' -f ($CommandNames[0..$_] -join '.')
    }

    $output = & $opCommand @Arguments @DefaultFlags
    try
    {
        $output | ConvertFrom-Json -ErrorAction Stop | Format-OPItem -TypeNames:$TypeNames
    }
    catch [ArgumentException]
    {
        $output
    }
}


# Adding an alias to easily invoke this without PSReadline suppressing the output because the command contains "password".
# I would use "op" but PowerShell refuses to autoload the module to use the alias -- _or_ a function -- if the op executable is in the PATHs.
# So going with the PowerShell alias convention ("i" == invoke).
New-Alias -Name 'iop' -Value 'Invoke-1Password'