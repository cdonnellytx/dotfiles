#!/usr/bin/env -S pwsh -NoProfile
#requires -Version 7 -Modules Microsoft.PowerShell.Utility
using namespace System.IO

<#
.SYNOPSIS
Ensure .magic.mgc exists if possible.
#>
[CmdletBinding(SupportsShouldProcess)]
[OutputType('Result')]
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
    try
    {
        Get-Command -CommandType Application -Name 'file' -ErrorAction Stop
    }
    catch
    {
        if ($IsWindows -and ($wsl = Get-Command -CommandType Application -Name 'wsl' | Select-Object -First 1) -and (& $wsl --status) -and $?)
        {
            
            if (& $wsl command -v file)
            {
                return { wsl file ($args | wslpath) }
            }
        }

        throw $_
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

$file = Get-FileCommand -ErrorAction Stop
$result = [Result]::new("Build magic file")

$magicFile = Join-Path $HOME '.magic.mgc'

# GNUCRAP: You can't specify the name of the compiled file, AND it assumes ${PWD} as the place to dump it.
if (!$PSCmdlet.ShouldProcess($magicItem, "Build magic file"))
{
    $result.Success = $true
    $result.Details += 'Dry run'
    return $result
}

$tmpdir = New-TemporaryDirectory

Push-Location $tmpdir
try
{
    & $file --magic-file "${HOME}/.magic.d" --compile
    if (!$?)
    {
        $result.Details += 'FAILED: magic file not compiled'
        return
    }

    # Should be one .mgc file.
    Get-ChildItem -Path '*.mgc' | Move-Item -Destination $magicFile -Force -ErrorAction Stop

    $result.Success = $true
    $result.Details += "OK"
    return $result
}
catch
{
    $result.Details += $_
    return $result
}
finally
{
    Pop-Location
    Remove-Item -Recurse $tmpdir -Force -ErrorAction Ignore
}
