#!/usr/bin/env -S pwsh -NoProfile
#requires -version 7.4

<#
.SYNOPSIS
Bootstraps the dotfiles into the home directory of the current user.
#>

using namespace System
using namespace System.Diagnostics.CodeAnalysis
using namespace System.IO

[CmdletBinding(SupportsShouldProcess)]
[SuppressMessageAttribute('PSUseCompatibleSyntax', '')] # this assumes latest.
param
(
    # The source directory.
    # Defaults to script location.
    [Parameter(Position = 0)]
    [ValidateNotNullOrEmpty()]
    [string] $Path = $PSScriptRoot,

    # The destination directory.
    # Defaults to the home directory.
    [Parameter(Position = 1)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({ Test-Path -Path $_ -PathType Container })]
    [string] $DestinationPath = $Home,

    # Set ACLs for ~/.ssh and ~/.gnupg.
    [switch] $ConfigureAcls,

    # Forcibly run options
    [Alias('f')]
    [switch] $Force,

    # Run all configure options.
    [switch] $All
)

Set-StrictMode -Version Latest

################################################################################
# Utils
################################################################################

function Confirm-PathIsContainer
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("Path")]
        [Alias("PSPath")]
        [Alias("LiteralPath")]
        [string[]] $paths
    )

    process
    {
        foreach ($path in $paths)
        {
            $item = Get-Item -LiteralPath $Path -Force -ErrorAction Ignore
            if ($item -is [DirectoryInfo])
            {
                # Path exists and is a container (folder).
                if ($item.Target)
                {
                    # REMINDER - symlinks in Windows can be file-links or directory-links.
                    # Just remove it.
                    Write-Verbose "Confirm-PathIsContainer: '${path}' already exists but is a symlink to '$($item.Target)'.  Removing."
                    Remove-Item -LiteralPath $item.FullName -ErrorAction Stop
                    Write-Verbose "Confirm-PathIsContainer: '${path}' removed."
                }
                else
                {
                    # NOT a symlink
                    Write-Verbose "Confirm-PathIsContainer: '${path}' already exists and is a container and NOT a symlink"
                    continue
                }
            }
            elseif ($item)
            {
                # Path exists and is NOT a container (folder).
                # Flag as error.
                Write-Verbose "Confirm-PathIsContainer: '${path}' already exists and is not a container"
                throw "${path}: is a leaf, not a container"
            }
            else
            {
                Write-Verbose "Confirm-PathIsContainer: '${path}' not found, will create."
            }

            # Item not found.  Create it or die.
            New-Item -Type Directory -Path $path -ErrorAction Stop | Out-Null
            Write-Verbose "Confirm-PathIsContainer: '${path}' created."
        }
    }
}

################################################################################
# Actions
################################################################################

function Update-SecurityAcl
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if ($IsWindows)
    {
        # An attempt.
        Write-Warning "ACLs not fixed.  You will need to fix them yourself."
        return
    }

    # SSH
    $sshDir = Join-Path $Path '.ssh'
    Confirm-PathIsContainer $sshDir
    chmod -R g-rwx, o-rwx $sshDir
    chmod u-wx "${sshDir}/authorized_keys" "${sshDir}/id_"*

    # GnuPG
    $gnupgDir = Join-Path $Path '.gnupg'
    Confirm-PathIsContainer $gnupgDir

    chmod -R g-rwx, o-rwx $gnupgDir
    #chmod u-wx "${sshDir}/authorized_keys" "${sshDir}/id_"*
}

################################################################################
# Main
################################################################################

###

# all:
#   - if All is set, All will be run.
#   - If any other Configure flag is set, user won't be asked.
#   - Otherwise, user will be asked.
$noToAll = !$All -and ($PSBoundParameters.GetEnumerator() | Where-Object { $_.Key -like 'Configure*' -and $_.Value -is [switch] -and $_.Value.IsPresent } | Select-Object -First 1)

# ACLs
if ($ConfigureAcls -or $PSCmdlet.ShouldContinue("Set security ACLs?", "Confirm Replace", [ref] $All, [ref] $noToAll))
{
    Update-SecurityAcl -Path $DestinationPath
}

