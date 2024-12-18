#requires -version 7 -Modules Microsoft.PowerShell.Utility, bootstrap.chezmoi, bootstrap.ux

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

$homeDir = Get-ChezmoiHomeDir

Invoke-Operation "Rebuild file '.magic.mgc'" {

    if (!($file = Get-FileCommand -ErrorAction Ignore))
    {
        Skip-Operation "'file' command not found"
    }

    $magicSourceDir = Join-Path $homeDir '.magic.d'
    $magicFile = Join-Path $homeDir '.magic.mgc'
    $tmpdir = New-TemporaryDirectory

    Push-Location $tmpdir
    try
    {
        & $file --magic-file $magicSourceDir --compile
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
        Remove-Item -Recurse -Force -ErrorAction Ignore
    }
}
