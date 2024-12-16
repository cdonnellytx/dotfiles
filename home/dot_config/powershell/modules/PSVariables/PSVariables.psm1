#requires -Version 4
<#
.SYNOPSIS
    Sets up important OS environment variables.
#>
param()

Set-StrictMode -Version Latest

$Exports = @{
    Variable = @()
}

if ($PSVersionTable.PSVersion.Major -lt 6)
{
    if ($PSVersionTable.PSVersion -lt '5.1')
    {
        # Variables introduced in PowerShell 5.1
        # $PSEdition = 'Desktop' or 'Core'.
        # Use "Desktop" on older systems ("Core" means the .NET Core version)
        New-Variable -Name 'PSEdition' -Value 'Desktop' -Option ReadOnly -Visibility Public -Scope Script -Description 'Edition information for the current PowerShell session'
        $Exports.Variable += @('PSEdition')
    }

    # Variables introduced in PowerShell 6.0
    # IsWindows / IsLinux / IsMacOS / IsCoreCLR
    # Safe to assume it's Windows and non-CoreCLR
    New-Variable -Name 'IsCoreCLR'  -Value $false -Option ReadOnly -Visibility Public -Scope Script -Description 'Flag indicating whether this is a CoreCLR prompt or not.'
    New-Variable -Name 'IsWindows'  -Value $true  -Option ReadOnly -Visibility Public -Scope Script -Description 'Flag indicating whether this OS is Windows.'
    New-Variable -Name 'IsLinux'    -Value $false -Option ReadOnly -Visibility Public -Scope Script -Description 'Flag indicating whether this OS is Linux.'
    New-Variable -Name 'IsMacOS'    -Value $false -Option ReadOnly -Visibility Public -Scope Script -Description 'Flag indicating whether this OS is macOS.'
    $Exports.Variable += @('IsWindows', 'IsLinux', 'IsMacOS', 'IsCoreCLR')
}

if (!(Test-Path Variable:Global:IsAdministrator))
{
    if ($IsWindows)
    {
        [bool] $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    }
    else
    {
        # Unix.  LATER: find a better way
        $isAdmin = $(id -u) -eq 0
    }

    New-Variable -Name IsAdministrator -Value $isAdmin -Option ReadOnly -Visibility Public -Scope Script -Description 'True if this user has administrator privileges.'
    $Exports.Variable += @('IsAdministrator')
}

####################################################################################################################################
# Unix environment variables
####################################################################################################################################

if (!$Env:HOME)
{
    if ($Env:USERPROFILE)
    {
        $Env:HOME = $Env:USERPROFILE
    }
    elseif ($Env:HOMEDRIVER)
    {
        $Env:HOME = "$Env:HOMEDRIVE$Env:HOMEPATH"
    }

    Write-Verbose "HOME set to '$Env:HOME'"
}

if (!$Env:USER)
{
    $Env:USER = $Env:USERNAME
    Write-Verbose "USER set to '$Env:USER'"
}

# Hostname.
# PowerShell 6.0 Core uses "NAME" as hostname on Linux.
if (!$Env:NAME)
{
    if ($Env:COMPUTERNAME)
    {
        $Env:NAME = $Env:COMPUTERNAME
    }
    elseif ($Env:HOSTNAME)
    {
        $Env:NAME = $Env:HOSTNAME
    }

    Write-Verbose "NAME set to '$Env:NAME'"
}

# PSModulePath.
# If you launch Desktop from Core on Windows, Desktop gets Core's PSModulePath.
# The opposite is *not* true for launching Core from Desktop, however.
if ($IsWindows -and $PSEdition -eq 'Desktop')
{
    $psCorePathGlobs = @(${Env:ProgramFiles}, ${Env:ProgramFiles(X86)}) | Where-Object { $_ } | ForEach-Object { "${_}\PowerShell\*" }

    # Group
    [string[]] $keep = @()
    [string[]] $remove = @()
    ($Env:PSModulePath -split ';') |
        ForEach-Object {
            $path = $_;
            if ($psCorePathGlobs | Where-Object { $path -like $_ })
            {
                # It's a PowerShell Core module path
                $remove += $_
            }
            else
            {
                $keep += $_
            }
        }

    if ($remove)
    {
        # There are PowerShell Core paths.
        # We must set Env:PSModulePath and then also reload any modules that came from the PowerShell Core paths.

        if ($VerbosePreference)
        {
            Write-Verbose "BEFORE:`nPSModulePath = ${Env:PSModulePath}`n$(Get-Module | Where-Object {
                $module = $_;
                $psCorePathGlobs | Where-Object { $module.Path -like $_ }
            } | Out-String)"
        }

        $Env:PSModulePath = $keep -join ';'

        Get-Module | Where-Object {
            $module = $_;
            $psCorePathGlobs | Where-Object { $module.Path -like $_ }
        } | ForEach-Object {
            Remove-Module -Name $_.Name # remove PS Core
            Import-Module -Name $_.Name # re-import PS Desktop
        }

        if ($VerbosePreference)
        {
            Write-Verbose "AFTER:`nPSModulePath = ${Env:PSModulePath}`n$(Get-Module | Where-Object {
                $module = $_;
                $psCorePathGlobs | Where-Object { $module.Path -like $_ }
            } | Out-String)"
        }
    }
}

#region Exports

Export-ModuleMember @Exports

#endregion
