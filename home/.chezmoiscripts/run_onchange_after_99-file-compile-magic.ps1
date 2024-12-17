#!/usr/bin/env -S pwsh -NoProfile
#requires -version 7 -Modules Microsoft.PowerShell.Utility, bootstrap.ux

using namespace System.IO
using namespace System.Management.Automation

<#
.SYNOPSIS
Ensure .magic.mgc exists if possible.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

<#
.SYNOPSIS
Creates a temporary directory which should be cleaned up later.
#>
function New-TemporaryDirectory
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([DirectoryInfo])]
    param()

    if (!$PSCmdlet.ShouldProcess([Path]::GetTempPath(), "New-TemporaryDirectory"))
    {
        return $null
    }

    # MSCRAP: Can't generate a unique temp file name without it creating the file.
    $tmpFile = New-TemporaryFile
    $tmpFile.Delete()

    mkdir $tmpFile
}

<#
.SYNOPSIS
Gets the `file` command.
#>
function Get-FileCommand
{
    [CmdletBinding()]
    [OutputType([CommandInfo])]
    [OutputType([scriptblock])]
    param()

    try
    {
        Get-Command -CommandType Application -Name 'file' -ErrorAction Stop | Select-Object -First 1
    }
    catch
    {
        if ($IsWindows -and (Get-Command -CommandType Application -Name 'wsl' | Select-Object -First 1))
        {
            if ((wsl --status) -and $? -and (wsl command -v file))
            {
                # return a script that wil invoke it and translate all arguments.
                return { wsl file ($args | wslpath) }
            }

            # nope, fall through.
        }

        Write-Error -ErrorRecord $_ -ErrorAction:$ErrorActionPreference
    }
}

class Result
{
    hidden [bool] $Success
    [string[]] $Details
    [string] $Description

    Result()
    {
        $this.Description = "Result"
    }

    Result([string] $description)
    {
        $this.Description = $description
    }
}

################################################################################

# GNUCRAP: You can't specify the name of the compiled file, AND it assumes ${PWD} as the place to dump it.
if (!$PSCmdlet.ShouldProcess($magicItem, "Build magic file"))
{
    $result.Success = $true
    $result.Details += 'Dry run'
    return $result
}

Invoke-Operation "Rebuild file '.magic.mgc'" {

    if (!($file = Get-FileCommand -ErrorAction SilentlyContinue))
    {
        return Skip-Operation "'file' command not found"
    }

    $magicFile = Join-Path $HOME '.magic.mgc'
    $tmpdir = New-TemporaryDirectory

    Push-Location $tmpdir
    try
    {
        & $file --magic-file "${HOME}/.magic.d" --compile
        if (!$?)
        {
            Write-Error 'FAILED: magic file not compiled'
            return
        }

        # Should be one .mgc file.
        Get-ChildItem -Path '*.mgc' | Move-Item -Destination $magicFile -Force -ErrorAction Stop
    }
    finally
    {
        Pop-Location
        Remove-Item -Recurse $tmpdir -Force -ErrorAction Ignore
    }
}