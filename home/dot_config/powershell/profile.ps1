<#
.SYNOPSIS
    PowerShell global profile script.
    Based on https://github.com/scottmuc/poshfiles
#>

#Requires -Version 5.1
#Requires -Modules Microsoft.PowerShell.Management, Microsoft.PowerShell.Utility
using namespace System.IO
using namespace System.Management.Automation

param()

# make scripting more strict
Set-StrictMode -Version Latest

# Capture the start time.
$profileStartTime = [DateTime]::UtcNow


function Get-ProfileScriptError([System.Management.Automation.ErrorRecord] $err)
{
    $count = 0
    for ($ex = $_.Exception; $ex; $ex = $ex.InnerException)
    {
        if ($count++ -gt 0) { "`n -----> " + $ex.ErrorRecord } else { $ex.ErrorRecord }
        if ($ex.ErrorRecord -and $ex.ErrorRecord.ScriptStackTrace)
        {
            "Script stack trace:"
            $ex.ErrorRecord.ScriptStackTrace
        }
    }
}

function Add-PSModulePath
{
    [OutputType([void])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    if (($Env:PSModulePath -split [Path]::PathSeparator) -contains $Path)
    {
        Write-Verbose "PSModulePath already contains '${Path}'"
        return
    }

    # Append the path to PSModulePath.
    switch -Wildcard ($Env:PSModulePath)
    {
        '' {
            # PSModulePath is empty
            Write-Verbose "PSModulePath is empty"
            $Env:PSModulePath = $Path
        }
        "*$([Path]::PathSeparator)" {
            # PSModulePath ends with PATH separator (: or ;)
            Write-Verbose "PSModulePath ends in SEPARATOR"
            $Env:PSModulePath += $Path
        }
        default {
            # PSModulePath contains other paths and does not end with a separator, add one.
            Write-Verbose "PSModulePath ends in NOT SEPARATOR"
            $Env:PSModulePath += [Path]::PathSeparator + $Path
        }
    }

    Write-Verbose "PSModulePath now contains '${Path}'"
}


function Add-DesktopModulePath
{
    [OutputType([void])]
    param
    (
    )

    $DocumentsPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
    $DocModulePath = [Path]::Combine($DocumentsPath, "WindowsPowerShell\Modules")

    Add-PSModulePath $DocModulePath
}

<#
.SYNOPSIS
Adds the nonstandard ~/.config/powershell/modules to PATH.
#>
function Add-ProfileModulePath
{
    [OutputType([void])]
    param
    (
    )

    $ProfileModulesPath = [Path]::Combine($PSScriptRoot, "modules")
    Add-PSModulePath $ProfileModulesPath
}

<#
.SYNOPSIS
Adds paths to PSModulePath.

.NOTES
Install-PSResource and Install-Module will install modules in:

- $DOCUMENTS\WindowsPowerShell - PowerShell Desktop
- $DOCUMENTS\PowerShell        - PowerShell (modern), Windows
- ~/.local/share/powershell    - PowerShell (modern), everywhere else
#>
function Add-ModulePath
{
    # Adds our special modules directories.
    # Note names are lowercase.
    if ($PSVersionTable.PSVersion.Major -lt 6 -or $PSEdition -eq 'Desktop')
    {
        # Desktop: Ensure its Documents modules are in PATH
        Add-DesktopModulePath
    }

    Add-ProfileModulePath
}

function Initialize-Profile
{
    [CmdletBinding(SupportsShouldProcess = $true)]
    param
    (
       [switch] $Timing,
       # Specifies the trace level for each line in a script. Each line is traced as it is run.
       # .FORWARDHELPTARGETNAME Set-PSDebug
       # .FORWARDHELPCATEGORY cmdlet
       [int] $Trace = 0,
       [TimeSpan] $WarningThreshold = [TimeSpan]::FromSeconds(0.3),
       [TimeSpan] $ErrorThreshold = [TimeSpan]::FromSeconds(3),

       # Specifies the depth for which to print the switch.
       # Defaults to 4.
       [uint32] $Depth = 4
    )

    # TODO when was ScriptStackTrace added? It's not in 2.0...
    #$DetailedErrorMinimumVersion = [Version]'3.0'

    if ($VerbosePreference)
    {
        Write-Verbose "Initialize-Profile`n`t-Timing:$Timing`n`t-Debug:$DebugPreference`n`t-Verbose:$VerbosePreference`n`t-WarningAction:$WarningPreference`n`t-ErrorAction:$ErrorActionPreference`n`t-InformationAction:$InformationPreference"
    }

    if ($DebugPreference)
    {
        $PSDefaultParameterValues['Import-Module:Debug'] = $DebugPreference
    }
    if ($VerbosePreference)
    {
        $PSDefaultParameterValues['Import-Module:Verbose'] = $VerbosePreference
    }

    Set-PSDebug -Trace:$Trace

    Add-ModulePath

    $importStopwatchElapsed = Measure-Command {
        Import-Module -Name posh-stopwatch -Scope Global
    }

    $ProfileStopwatch = Invoke-CommandWithStopwatch -PassThru -Name 'Profile' -Command {
        Add-Elapsed 'posh-stopwatch' $importStopwatchElapsed
        # Need the functions directories:
        #   - shared the shared one and the item-specific one.
        $profileName = [Path]::GetFileNameWithoutExtension($profile) -replace '_profile$', ''
        $functionsBaseDir = [Path]::Combine($PSScriptRoot, 'functions')
        $functionsDirs = @(
            $functionsBaseDir,
            [Path]::Combine($functionsBaseDir, 'editions', $PSEdition)
            [Path]::Combine($functionsBaseDir, 'profiles', $profileName)
        )

        Write-Verbose "functionsDirs: ${functionsDirs}"

        # function loader
        #
        # if you want to add functions you can added scripts to your
        # powershell profile functions directory or you can inline them
        # in this file. Ignoring the dot source of any tests
        #
        # cdonnelly 2020-04-27: Using dot sourcing again.
        # Previously loaded scripts per https://becomelotr.wordpress.com/2017/02/13/expensive-dot-sourcing/.
        # Performance gain is either reduced to irrelevance or no longer there as of Windows 10 1909 / SEP 14 RU2 MP1.
        $functionsDirs |
            Where-Object { Test-Path -Type Container $_ } |
            ForEach-Object { Resolve-Path -Path ([Path]::Combine($_, '*.ps1')) } |
            Where-Object { -not ($_.ProviderPath.Contains(".Tests.")) } |
            Get-Item |
            Sort-Object Name, FullName |
            ForEach-Object {
                Invoke-CommandWithStopwatch -Name $_.FullName -InputObject $_ -Command {
                    $fullName = $_.FullName
                    try
                    {
                        Write-Verbose "ENTRY ${fullName}"
                        . $fullName
                        Write-Verbose "EXIT  ${fullName}"
                    }
                    catch
                    {
                        try
                        {
                            $errors = Get-ProfileScriptError $_
                            Write-Error "Cannot process script '${fullName}':`n$errors"
                        }
                        catch
                        {
                            Write-Error "Cannot process script '${fullName}', nor get error message: $_"
                        }
                    }
                }
            }
    }

    # Also store it globally
    Set-Variable -Name ProfileTimingInfo -Value $ProfileStopwatch -Scope Global -Option ReadOnly

    if ($timing -or $ProfileStopwatch.Elapsed -ge $ErrorThreshold)
    {
        # Write enough.
        Write-Stopwatch $ProfileStopwatch -WarningThreshold $WarningThreshold -ErrorThreshold $ErrorThreshold -Depth $Depth
    }
    elseif ($Host.Name -ceq 'ConsoleHost')
    {
        # The default PowerShell host (Core and Desktop as of 5.0) prints a loading summary of personal and system profiles.
        # Everyting else does not.
    }
    else
    {
        # This comes closest to what they are doing (50-100ms difference).
        Write-Information -InformationAction Continue -MessageData ('Loading personal and system profiles took {0:F0}ms.' -f ([DateTime]::UtcNow - $profileStartTime).TotalMilliseconds) -Tags 'Profile', 'Timing'
    }
}

function _IsTruthy($x)
{
    switch ($x)
    {
        '' { return $false }
        '0' { return $false }
        'false' { return $false }
        default { return $true }
    }
}

try
{
    $splat = @{}
    if (_IsTruthy($Env:PROFILE_D_TIMING))
    {
        $splat.Timing = $true
        # PowerShell 7 and later: we allow it to be JSON.
        # (Desktop has too many stupid limitations with ConvertFrom-JSON to make it viable there.)
        if ($PSVersionTable.PSVersion.Major -ge 7 -and ($json = ConvertFrom-Json $Env:PROFILE_D_TIMING -AsHashtable -ErrorAction Ignore) -is [Hashtable])
        {
            # PROFILE_D_TIMING is a JSON object, use its splat.
            $splat += $json
        }
    }
    if (_IsTruthy($Env:PROFILE_D_TRACE))       { $splat.Trace               = $Env:PROFILE_D_TRACE }
    if (_IsTruthy($Env:PROFILE_D_DEBUG))       { $splat.Debug               = $true }
    if (_IsTruthy($Env:PROFILE_D_VERBOSE))     { $splat.Verbose             = $true }
    if (_IsTruthy($Env:PROFILE_D_ERRORACTION)) { $splat.ErrorAction         = $Env:PROFILE_D_ERRORACTION }
    if (_IsTruthy($Env:PROFILE_D_WARNING))     { $splat.WarningAction       = $Env:PROFILE_D_WARNING }
    if (_IsTruthy($Env:PROFILE_D_INFORMATION)) { $splat.InformationAction   = [ActionPreference]::Continue }

    Initialize-Profile @splat
}
catch
{
    Write-Error "Failed to initialize profile: ${_}"
}
finally
{
    Remove-Item -Confirm:$false Variable:Splat, Variable:profileStartTime, Function:_IsTruthy -ErrorAction Ignore
}
