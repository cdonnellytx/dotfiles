#Requires -Version 5
#Requires -Modules Posh-TerminalId

using namespace System

<#
.SYNOPSIS
Color terminal support.
#>

param()

Set-StrictMode -Version Latest

# Only do things if the environment is interactive and not redirected.
# @see https://stackoverflow.com/questions/9738535/powershell-test-for-noninteractive-mode
if (![Environment]::UserInteractive -or [Console]::IsOutputRedirected)
{
    return
}

if ($Env:COLORTERM) { return }

switch ($PSTerminalInfo.ColorCount)
{
    16777216
    {
        $Env:COLORTERM = 'truecolor'
        return
    }

    # This one is a guess right now.
    256
    {
        if ($IsWindows)
        {
            # They bothered to set it on Windows, so assume truecolor
            $Env:COLORTERM = 'truecolor'
            return
        }

        # All other systems: Assume everyone is doing the right thing.
        $Env:COLORTERM = '256color'
        return
    }

    16
    {
        $Env:COLORTERM = 'color'
        return
    }
}
