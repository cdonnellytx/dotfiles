using namespace System.IO
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Management.Automation

[SuppressMessageAttribute('PSAvoidGlobalVars', 'Global:ImportModuleQueue')]
param()

<#
.SYNOPSIS
    Module loading: Some modules need to be loaded explicitly in all versions; others need explicit loading only if autoloading isn't on
    (either module autoloading is disabled on this host (really?) or we're on an old version of PowerShell that doesn't support implicit module loading).
#>
Set-StrictMode -Version Latest

class ModuleInfo
{
    [ValidateNotNullOrEmpty()]
    [string] $Name

    [object[]] $ArgumentList

    [ValidateSet('Global', 'Local')]
    [string] $Scope = 'Global'

    [ActionPreference] $ErrorAction = [ActionPreference]::Stop

    [scriptblock] $Condition

    [scriptblock] $Loaded

    [bool] $Deferred

    [ActionPreference] $VerbosePreference = $global:VerbosePreference

    ModuleInfo()
    {
    }

    ModuleInfo([string] $name)
    {
        $this.Name = $name
    }

    ModuleInfo([string] $name, [scriptblock] $condition)
    {
        $this.Name = $name
        $this.Condition = $condition
    }

    ModuleInfo([string] $name, [scriptblock] $condition, [bool] $deferred)
    {
        $this.Name = $name
        $this.Condition = $condition
        $this.Deferred = $deferred
    }

    static [ModuleInfo] Deferred([string] $name)
    {
        return [ModuleInfo]::new($name, $null, $true)
    }

    static [ModuleInfo] Deferred([string] $name, [scriptblock] $condition)
    {
        return [ModuleInfo]::new($name, $condition, $true)
    }

    [void] Import()
    {
        Invoke-CommandWithStopwatch -Name $this.Name -Command {
            if ($this.VerbosePreference) { Write-Verbose "ENTRY Import-Module $($this.Name)" -Verbose }

            if ($this.Condition)
            {
                if ($this.VerbosePreference) { Write-Verbose "$($this.Name) - testing condition {$($this.Condition)}" -Verbose }
                if (!(& $this.Condition))
                {
                    if ($this.VerbosePreference) { Write-Verbose "     => false" -Verbose }
                    return
                }
                if ($this.VerbosePreference) { Write-Verbose "     => true" -Verbose }
            }

            $isLoaded = $false
            if ($this.VerbosePreference) { Write-Verbose "ENTRY Import-Module Block $($this.Name)" -Verbose }
            try
            {
                Import-Module -Name:$this.Name -ArgumentList:$this.ArgumentList -ErrorAction:$this.ErrorAction -Verbose:$this.VerbosePreference
                $isLoaded = $true
            }
            catch
            {
                # cdonnelly 2018-09-27: Write-Error here seems to not work.  No idea why.
                $br = [Environment]::NewLine
                Write-Warning "Failed to import module $($this.Name): ${_}${br}Stack trace:${br}$($_.ScriptStackTrace -replace '(?m)^', "    ")"
            }
            finally
            {
                if ($this.VerbosePreference)
                {
                    Write-Verbose "EXIT  Import-Module Block $($this.Name)" -Verbose
                }
            }

            if ($isLoaded -and $this.Loaded)
            {
                & $this.Loaded
            }

            if ($this.VerbosePreference) { Write-Verbose "EXIT  Import-Module $($this.Name)" -Verbose }
        }
    }
}

#
# Some shell implementations don't support deferring properly.
#
$Deferrable = switch ([Path]::GetFileNameWithoutExtension($PROFILE))
{
    # 'Microsoft.VSCode_profile' { $false }
    default { $true }
}

# Modules not loaded here:
#   - KnownFolders - cdonnelly 2017-05-16: nothing in profile needs it anymore.  Set the PATH manually.

[ModuleInfo[]] $modules = [ModuleInfo[]] @(
    'PSReadLine'                                # required to be loaded for command history to work
    'PSVariables'                               # polyfill + more
    'Posh-TerminalId'
    @{                                          # must be loaded to remove bad aliases
        Name = 'CoreAliases'
        Deferred = $false
        ArgumentList = @(
            # PSCRAP: Module arguments appear to be ONLY order-dependent.
            # Include
            @(
                # These are too much in my PS muscle memory
                'ls',
                'cp', 'mv', 'rm', 'rmdir',
                'cd', 'pwd',
                'cat',
                'clear', 'echo'
                #
                'kill', 'sort',
                # Meh
                'dir', 'chdir', 'ri', 'sleep',
                # YES
                'which'
            ),
            # Exclude
            @(
                # Truly dangerous
                'curl', 'wget',
                # Annoying
                'diff', 'compare'
                # Trying to remove these
                'lp', 'man', 'mount', 'ps', 'tee', 'cpp'
            )
        )
    }
    # required for z's cd alias to be loaded and work
    'z'
    # Use PSPager with PowerShell Desktop.
    # Core honors the PAGER environment variable, Desktop doesn't.
    [ModuleInfo]::new('PSPager', { $PSEdition -eq 'Desktop' })

    # Pansies and friends: virtual terminal required
    #[ModuleInfo]::new('Pansies', { $host.UI.SupportsVirtualTerminal })
    #[ModuleInfo]::new('Pansies.Colors', { $host.UI.SupportsVirtualTerminal })
    [ModuleInfo]::Deferred('Terminal-Icons', { $host.UI.SupportsVirtualTerminal })
    [ModuleInfo] @{
        Name = 'DockerCompletion'
        Condition = { $IsCoreCLR -and (Get-Command 'docker' -ErrorAction Ignore) }
        ErrorAction = 'Ignore'
        Deferred = $true
    }
    [ModuleInfo] @{
        Name = 'DotnetCompletion'
        Condition = { Get-Command 'dotnet' -ErrorAction Ignore }
        Deferred = $true
    }

    # Superior environment variable commands
    [ModuleInfo]::Deferred('EnvironmentHelper')

    # Style theme modules
    [ModuleInfo]::new('PSStyleTheme', { $PSEdition -eq 'Core' -and $PSVersionTable.PSVersion -ge '7.2' })
    [ModuleInfo]::new('PSConsoleTheme', { $PSEdition -eq 'Desktop' -and $host.UI.SupportsVirtualTerminal })

    [ModuleInfo] @{
        # Load posh-git for tab completion only.
        Name = 'posh-git'
        Loaded = {
            # oh-my-posh needs this.
            # @see https://ohmyposh.dev/docs/segments/scm/git#posh-git
            function global:Set-PoshGitStatus
            {
                [SuppressMessageAttribute('PSAvoidGlobalVars', 'Global:GitStatus')]
                [SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'GitStatus')]
                param()

                $global:GitStatus = posh-git\Get-GitStatus
            }

            New-Alias -Name Set-PoshContext -Value 'Set-PoshGitStatus' -Scope Global -Force
        }
        Deferred = $true
    }
    # Load posh-gh for tab completion only.
    [ModuleInfo]::Deferred('posh-gh')
)

if ($VerbosePreference)
{
    Write-Verbose "PSModulePath:`n$($Env:PSModulePath -split ';' | ConvertTo-Json)"
}

$importModuleQueue = [List[ModuleInfo]]::new()

foreach ($module in $modules)
{
    $module.VerbosePreference = $VerbosePreference # otherwise it will NOT take
    if ($VerbosePreference) { Write-Verbose "ENTRY Module $($module.Name)" }

    if ((Get-Module -ErrorAction Ignore -Name $module.Name))
    {
        if ($VerbosePreference) { Write-Verbose "EXIT  Module $($module.Name) - already loaded" }
        continue
    }

    if ($Deferrable -and $module.Deferred)
    {
        $importModuleQueue.Add($module)
    }
    else
    {
        $module.Import()
    }

    if ($VerbosePreference) { Write-Verbose "EXIT  Module $($module.Name)" }
}

if ($importModuleQueue.Count -gt 0)
{
    Invoke-CommandWithStopwatch -Name 'RegisterDeferredCallback' -Command {
        # .NETCRAP: Cannot pass an object to an engine event. So we have to use a global variable.
        # However, we limit the scope to just the boundary of the event.
        $Global:ImportModuleQueue = $importModuleQueue

        $null = Register-EngineEvent -SourceIdentifier ([PsEngineEvent]::OnIdle) -MaxTriggerCount 1 -Action {
            [List[ModuleInfo]] $importModuleQueue = $Global:ImportModuleQueue
            Remove-Variable -Scope Global -Name 'ImportModuleQueue'

            Write-Verbose "ENTRY deferred callback"
            $Stopwatch = Invoke-CommandWithStopwatch -PassThru -Name 'DeferredCallback' -Command {
                try
                {
                    foreach ($module in $importModuleQueue)
                    {
                        $module.Import()
                    }
                }
                catch
                {
                    Write-Warning "err $_"
                    throw $_
                }
                finally
                {
                    # Remove current Job (No Need to get job result)
                    $EventSubscriber.Action | Remove-Job -Force -ErrorAction Ignore
                }
            }

            Set-Variable -Name DeferredProfileTimingInfo -Value $Stopwatch -Scope Global -Option ReadOnly
            Write-Verbose "EXIT  deferred callback"

        }
    }
}


# Update defaults
if (Test-Path 'Variable:\PSDefaultParameterValues')
{
    if ($PSVersionTable.PSVersion.Major -lt 6)
    {
        # Desktop: Install-Module: default to user (Core already does this)
        $PSDefaultParameterValues['Install-Module:Scope'] = 'CurrentUser'
        $PSDefaultParameterValues['Update-Module:Scope'] = 'CurrentUser'
    }

    # Finally, do NOT allow newer modules to clobber older stuff by default.
    # @see https://www.darkoperator.com/blog/2013/2/26/powershell-basicsndashrecommendations-when-importing-modules.html
    $PSDefaultParameterValues['Import-Module:NoClobber'] = $true
}
