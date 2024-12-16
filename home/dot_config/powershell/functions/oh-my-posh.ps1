#Requires -Version 5
#Requires -Modules Microsoft.PowerShell.Utility, Posh-TerminalId

Set-StrictMode -Version Latest

Push-Stopwatch 'Terminal checks'
try
{
    if (!$Host.UI.SupportsVirtualTerminal)
    {
        # oh-my-posh won't work.
        # It needs $Host.UI.RawUI.WindowSize.Width to function correctly.
        Write-Verbose "oh-my-posh: host does not support virtual terminal"
        return
    }
}
finally
{
    Pop-Stopwatch
}

Write-Debug "Initializing oh-my-posh (theme: ${Env:POSH_THEME})"

Push-Stopwatch 'Get-Command'
try
{
    if (!($ohMyPosh = Get-Command -Name 'oh-my-posh' -ErrorAction Ignore))
    {
        # Machine isn't set up yet probably.  Don't compound warnings.
        Write-Verbose "oh-my-posh: command not found"
        return
    }
}
finally
{
    Pop-Stopwatch
}

if ($PSVersionTable.PSVersion.Major -ge 7)
{
    $uptime = Get-Uptime

    if ($uptime -lt [timespan]::FromDays(1))
    {
        $path = [IO.Path]::Combine($Env:TEMP, ("oh-my-posh-debug.{0:yyyyMMddHHmmss}.log" -f ([System.DateTimeOffset]::UtcNow - $uptime)))
        if (!(Test-Path $path))
        {
            Push-Stopwatch 'oh-my-posh init pwsh --debug'
            try
            {
                & $ohMyPosh init pwsh --config $Env:POSH_THEME --debug --print > $path
            }
            finally
            {
                Pop-Stopwatch
            }
        }
    }
}

# Why is invoking it with --print 20-30% faster? One less iteration of Invoke-Expression maybe?
Push-Stopwatch 'oh-my-posh init pwsh --print'
try
{
    $script = (& $ohMyPosh init pwsh --config $Env:POSH_THEME --print) -join ([System.Environment]::NewLine)
}
finally
{
    Pop-Stopwatch
}

Push-Stopwatch '[ScriptBlock]::Create'
try
{
    $script:command = [ScriptBlock]::Create($script)
}
finally
{
    Pop-Stopwatch
}

Invoke-CommandWithStopwatch -Name 'eval' -Command $command

if (!$?)
{
    Write-Error "oh-my-posh initialization failed, theme '${Env:POSH_THEME}'.`n${ev}"
    return
}

if ($VerbosePreference)
{
    Write-Verbose "oh-my-posh initialized, theme '${Env:POSH_THEME}', script: $command"
}

# OMPCRAP: If there is an Azure segment in the theme, prompt assumes Get-AzContext (from the Az.Accounts module) exists.
# If it is set true and the module doesn't exist, set the value to false so we don't generate an error every time the prompt shows.
if (($varAzure = Get-Variable -Name '_ompAzure' -Scope Global -ErrorAction Ignore) -and $varAzure.Value)
{
    $varAzure.Value = !!(Get-Module -Name 'Az.Accounts')
    if ($VerbosePreference)
    {
        Write-Verbose "oh-my-posh: _ompAzure == $($varAzure.Value)"
    }
}
