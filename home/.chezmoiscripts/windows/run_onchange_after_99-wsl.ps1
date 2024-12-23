#requires -version 7 -modules bootstrap.environment, bootstrap.wslenv

<#
.SYNOPSIS
Sets WSL-related items.

.DESCRIPTION

Set core WSL environment variables, such as:
- WSL_UTF8 - forces the `wsl` command in Windows to output as UTF-8 (default is UTF-16LE).
- WSLENV - adds WSL_UTF8 to the list.

Also ensure WSL is up-to-date.

#>
[CmdletBinding(SupportsShouldProcess)]
param()

# https://github.com/microsoft/WSL/issues/4607#issuecomment-1197258447
# NOTE: this causes WSL distros to appear as malformed gibberish (Chinese characters).
# Set it in process so we get the benefit of it later in-script.
Set-EnvironmentVariable @PSBoundParameters -Target User, Process -Name 'WSL_UTF8' -Value '1'
Add-WSLEnvironment @PSBoundParameters -Target User, Process -Value 'WSL_UTF8'

Get-Command -Name 'wsl' -CommandType Application > $null

switch -regex (wsl --status)
{
    "^$" {} # eat empties
    "Default Version: (\d+)"
    {
        [int] $version = $matches[1]
        switch ($version)
        {
            1
            {
                wsl --set-default-version 2
                $version = 2
            }
            2
            {
                # do nothing
            }
            default
            {
                Write-Warning "Unsupported default version '$_'"
            }
        }
    }

    "The WSL 2 kernel file is not found"
    {
        wsl --update
        wsl --shutdown
    }

    "Default distribution: "
    {
        Write-Verbose "[wsl] $_"
    }

    default
    {
        Write-Warning "[wsl] $_"
    }
}

# Add my PROFILE_D_xxx environment vars to WSL environment passthru.
Add-WSLEnvironment -Target User, Process -Value (
    'PROFILE_D_OUTPUT',
    'PROFILE_D_TIMING',
    'PROFILE_D_VERBOSE',
    'PROFILE_D_CACHE'
) @PSBoundParameters
