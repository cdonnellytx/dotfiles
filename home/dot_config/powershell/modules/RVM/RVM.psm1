Using Namespace System.Collections.Generic
Using Namespace System.Diagnostics.CodeAnalysis
Using Namespace System.Management.Automation

param
(
)

<#
.SYNOPSIS
Represents a Ruby version.

.LINK
    https://en.wikipedia.org/wiki/Ruby_MRI
.LINK
    https://www.ruby-lang.org/en/news/2013/12/21/ruby-version-policy-changes-with-2-1-0/
#>
class RubyVersion
{
    <#
    The major version.

    MRI Ruby: Increased when incompatible change which can’t be released in `Minor`.
        - Reserved for special events.
    #>
    [int] $Major = 0

    <#
    The minor version.

    MRI: Increased every Christmas, may be API incompatible.
    #>
    [int] $Minor = 0

    <#
    The "teeny" version.

    MRI Ruby:  Security or bug fix which maintains API compatibility.
        - May be increased more than 10 (such as 2.1.11), and will be released every 2-3 months.
    #>
    [int] $Teeny = -1

    <#
    The patch release.

    MRI Ruby: represents the number of commits since last `Minor` release (will be reset at 0 when releasing `Minor`).
    #>
    [int] $Patch = -1

    RubyVersion([int] $Major, [int] $Minor)
    {
        $this.Major = $Major
        $this.Minor = $Minor
    }

    RubyVersion([int] $Major, [int] $Minor, [int] $Teeny)
    {
        $this.Major = $Major
        $this.Minor = $Minor
        $this.Teeny = $Teeny
    }

    RubyVersion([int] $Major, [int] $Minor, [int] $Teeny, [int] $Patch)
    {
        $this.Major = $Major
        $this.Minor = $Minor
        $this.Teeny = $Teeny
        $this.Patch = $Patch
    }

    RubyVersion([string] $Value)
    {
        $other = [RubyVersion]::Parse($Value)
        $this.Major = $other.Major
        $this.Minor = $other.Minor
        $this.Teeny = $other.Teeny
        $this.Patch = $other.Patch
    }

    [string] ToString()
    {
        $result = "{0}.{1}" -f $this.Major, $this.Minor

        if ($this.Teeny -ge 0)
        {
            $result += ".{0}" -f $this.Teeny
        }

        if ($this.Patch -ge 0)
        {
            $result += "-p{0}" -f $this.Patch
        }

        return $result
    }

    [bool] Equals([object] $other)
    {
        return $other -is [RubyVersion] -and
            $this.Major -eq $other.Major -and
            $this.Minor -eq $other.Minor -and
            $this.Teeny -eq $other.Teeny -and
            $this.Patch -eq $other.Patch
    }

    [int] GetHashCode()
    {
        return $this.Major -shl 24 + $this.Minor -shl 16 + $this.Teeny -shl 8 + $this.Patch
    }

    hidden static [regex] $RubyVersionPattern = @'
(?x)
    ^
    (?<Major>\d+) \. (?<Minor>\d+)
    (?:
        \. (?<Teeny>\d+)
        (?: [.-]p? (?<Patch>\d+) )?
    )?
    $
'@

    static [RubyVersion] Parse([string] $value)
    {
        [RubyVersion] $result = $null
        if ([RubyVersion]::TryParse($value, [ref] $result))
        {
            return $result
        }
        throw [System.ArgumentOutOfRangeException]::new('value', $value, 'Cannot parse version')
    }

    static [bool] TryParse([string] $value, [ref] $refVersion)
    {
        $m = [RubyVersion]::RubyVersionPattern.Match($value)
        if (!$m.Success)
        {
            return $false
        }

        $refVersion.Value = if ($m.Groups['Patch'].Success)
        {
            [RubyVersion]::new($m.Groups['Major'].Value, $m.Groups['Minor'].Value, $m.Groups['Teeny'].Value, $m.Groups['Patch'].Value)
        }
        elseif ($m.Groups['Teeny'].Success)
        {
            [RubyVersion]::new($m.Groups['Major'].Value, $m.Groups['Minor'].Value, $m.Groups['Teeny'].Value)
        }
        else
        {
            [RubyVersion]::new($m.Groups['Major'].Value, $m.Groups['Minor'].Value)
        }

        return $true
    }
}

class RubyInstallManager
{
    [void] Install([string] $Version) { throw [System.NotImplementedException]::new() }
    [VersionInfo[]] GetAvailableVersions() { throw [System.NotImplementedException]::new() }
    [VersionInfo[]] GetInstalledVersions() { throw [System.NotImplementedException]::new() }
}

class RvmRubyInstallManager : RubyInstallManager
{

}

class WindowsRubyInstallManager : RubyInstallManager
{
    [void] Install([string] $Version)
    {
        switch ($Version)
        {
            '' { winget install --id 'RubyInstallerTeam.Ruby' }
            'latest' { winget install --id 'RubyInstallerTeam.Ruby' }
            default
            {
                winget install --id 'RubyInstallerTeam.Ruby' --version $Version
            }
        }
    }

    [VersionInfo[]] GetInstalledVersions()
    {
        return Get-ChildItem -LiteralPath 'HKCU:\SOFTWARE\RubyInstaller\MRI' | ForEach-Object {
            [VersionInfo] @{
                Version = $_.PSChildName
                Platform = $_.GetValue('BuildPlatform')
                Path = $_.GetValue('InstallLocation')
                Command = Get-Command -Name (Join-Path $_.GetValue('InstallLocation') 'bin/ruby.exe') -Type Application
            }
        }
    }

    [VersionInfo[]] GetAvailableVersions()
    {
        # MSCRAP: You can't suppress command header output
        return winget show --id RubyInstallerTeam.Ruby --versions |
            Where-Object { $_ -match '^\d\.' } |
            ForEach-Object { [VersionInfo]::new([RubyVersion]::Parse($_)) }
    }
}

function Resolve-InstallManager
{
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (Get-Command -Name 'rvm' -CommandType Application, Script -ErrorAction Ignore)
    {
        return [RvmRubyInstallManager]::new()
    }

    if ($IsWindows)
    {
        return [WindowsRubyInstallManager]::new()
    }

    Write-Error "No implementations found"
    return
}

class VersionInfo
{
    [RubyVersion] $Version
    [string] $Path
    [CommandInfo] $Command
    [string] $Platform
    # Indicates this is the default install.
    [bool] $Default

    VersionInfo()
    {
    }

    VersionInfo([RubyVersion] $Version)
    {
        $this.Version = $Version
    }
}

#
# Cache
#
class RubyVersionCache
{
    [datetime] $Expiration
    [Dictionary[RubyVersion, VersionInfo]] $Versions = @{}
    [Dictionary[string, RubyVersion]] $InexactVersionMap = @{}

    [VersionInfo] GetDefault()
    {
        $list = $this.GetList()
        if ($list.Count -eq 0)
        {
            throw [InvalidOperationException]::new("No Ruby versions installed");
        }

        $result = $list | Where-Object 'Default' | Select-Object -First 1
        if ($result)
        {
            return $result
        }

        return $this.GetLatest()
    }

    [VersionInfo] GetLatest()
    {
        $list = $this.GetList()
        if ($list.Count -eq 0)
        {
            throw [InvalidOperationException]::new("No Ruby versions installed");
        }

        return $list | Sort-Object -Descending Version | Select-Object -First 1
    }

    [IEnumerable[VersionInfo]] GetList()
    {
        $this.RefreshIfNeeded()
        return $this.Versions.Values
    }

    [bool] IsInstalled([RubyVersion] $Version)
    {
        return $this.Versions.ContainsKey($Version)
    }

    [VersionInfo] Get([string] $Version)
    {
        $this.RefreshIfNeeded()

        [RubyVersion] $exactVersion = $null;
        if ([RubyVersion]::TryParse($Version, [ref] $exactVersion))
        {
            return $this.Get($exactVersion)
        }

        if ($this.InexactVersionMap.TryGetValue($Version, [ref] $exactVersion))
        {
            return $this.Versions[$exactVersion]
        }

        Write-Error -Category ObjectNotFound -Message "Version '${Version}' was not found."
        return $null
    }

    [VersionInfo] Get([RubyVersion] $Version)
    {
        $this.RefreshIfNeeded()

        [VersionInfo] $result = $null
        if ($this.Versions.TryGetValue($Version, [ref] $result))
        {
            return $result
        }

        [RubyVersion] $exactVersion = $null
        if ($this.InexactVersionMap.TryGetValue($Version, [ref] $exactVersion))
        {
            return $this.Versions[$exactVersion]
        }

        Write-Error -Category ObjectNotFound -Message "Version '${Version}' was not found."
        return $null
    }

    hidden [void] Add([VersionInfo] $info)
    {
        $this.Versions.Add($info.Version, $info)
        $this.InexactVersionMap.Add($info.Version, $info.Version)

        $majorMinor = [RubyVersion]::new($info.Version.Major, $info.Version.Minor)
        [RubyVersion] $exactVersion = $null
        if (!$this.InexactVersionMap.TryGetValue($majorMinor, [ref] $exactVersion) -or $exactVersion -lt $info.Version)
        {
            $this.InexactVersionMap[$majorMinor] = $info.Version

            if (!$this.InexactVersionMap.TryGetValue($info.Version.Major, [ref] $exactVersion) -or $exactVersion -lt $info.Version)
            {
                $this.InexactVersionMap[$info.Version.Major] = $info.Version
            }
        }
    }

    hidden [void] Clear()
    {
        $this.Versions.Clear()
        $this.InexactVersionMap.Clear()
    }

    [void] RefreshIfNeeded() { $this.Refresh($false) }

    [void] Refresh([bool] $Force)
    {
        if (!$Force -and $this.Expiration -gt [DateTime]::UtcNow)
        {
            return
        }

        $versionList = Get-InstalledRubyVersion | Sort-Object Version

        $this.Clear()
        foreach ($version in $versionList)
        {
            $this.Add($version)
        }

        $this.Expiration = [DateTime]::UtcNow
    }
}

$Script:Cache = [RubyVersionCache]::new()

#
# Cmdlets
#

<# .PRIVATE #>
function Get-InstalledRubyVersion
{
    [OutputType([VersionInfo])]
    param()

    return $Script:InstallManager.GetInstalledVersions()
}

function Install-RubyVersion
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -eq 'latest' -or [RubyVersion] $_ })]
        [string[]] $Version
    )

    if (!$PSCmdlet.ShouldProcess("Versions: ${Version}", "Install Ruby"))
    {
        return
    }

    foreach ($v in $Version)
    {
        $Script:InstallManager.Install($v)
    }
}

function Uninstall-RubyVersion
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ $_ -eq 'latest' -or [RubyVersion] $_ })]
        [string[]] $Version
    )

    if (!$PSCmdlet.ShouldProcess("Versions: ${Version}", "Uninstall Ruby"))
    {
        return
    }


    foreach ($v in $Version)
    {
        $Script:InstallManager.Uninstall($v)
    }
}

function Invoke-Ruby()
{
    [CommandInfo] $cmd = if ($Script:Current) { $Script:Current.Command } else { Get-Command -Name 'ruby' -CommandType Application -ErrorAction Stop }
    & $cmd $args
}

[VersionInfo] $Script:Current = $null

function Use-RubyVersion
{
    [CmdletBinding(DefaultParameterSetName = 'version')]
    param
    (
        [Parameter(ParameterSetName = 'version', Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Version,

        [Parameter(ParameterSetName = 'latest')]
        [switch] $Latest,

        [Parameter(ParameterSetName = 'default')]
        [switch] $Default,

        [Parameter(ParameterSetName = '*')]
        [switch] $PassThru
    )

    process
    {
        if ($Default)
        {
            $Script:Current = $null
        }
        elseif ($Latest)
        {
            $Script:Current = $Script:Cache.GetLatest()
        }
        else
        {
            $Script:Current = $Script:Cache.Get($Version)
        }

        $Env:RVM_CURRENT_VERSION = if ($Script:Current) { $Script:Current.Version.ToString() } else { '' }

        if ($PassThru)
        {
            return $Script:Current
        }
    }
}

<#
.SYNOPSIS
Gets the current version.
#>
function Get-CurrentRubyVersion
{
    [CmdletBinding()]
    [OutputType([VersionInfo])]
    param()

    return $Script:Current
}

function Get-RubyVersion
{
    [CmdletBinding()]
    param
    (
        [Parameter()]
        [switch] $Current,

        [Parameter()]
        [Alias('known')]
        [switch] $Available
    )

    $items = $Script:Cache.GetList()

    if ($Available)
    {
        return $Script:InstallManager.GetAvailableVersions() |
            Sort-Object Version -Descending |
            Select-Object -Property Version, @{ Name = 'Installed'; Expression = { if ($Script:Cache.IsInstalled($_.Version)) { 'Installed' } else { '' } } }
    }

    if ($Current)
    {
        $items = Get-CurrentRubyVersion
    }

    $items | Sort-Object Version -Descending |
        Select-Object `
            Version,
        @{ Name = 'Current'; Expression = {
            Write-Warning "_ vs current = $($_, $Script:Current | ft | Out-String)"
            $global:a = @($_, $Script:Current)
            if ($_.Version -eq $Script:Current.Version) { 'Current' } else { '' } } },
        Path
}

function Start-RVM
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (!$PSCmdlet.ShouldProcess('Start RVM'))
    {
        return
    }

    Use-RubyVersion -Latest
}

function Stop-RVM
{
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if (!$PSCmdlet.ShouldProcess('Stop RVM'))
    {
        return
    }

    $Script:Current = $null
    $Env:RVM_CURRENT_VERSION = ''
}

function Invoke-RVM
{
    [SuppressMessageAttribute("PSShouldProcess", "")] # Because PSScriptAnalyzer team refuses to listen to reason. See bugs:  #194 #283 #521 #608
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The name of the command to invoke.
        [Parameter(Position = 0, Mandatory)]
        [ValidateSet('use', 'list', 'install', 'uninstall', 'on', 'off')]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # The list of arguments to pass to the command.
        [Parameter(ValueFromRemainingArguments)]
        [ValidateNotNullOrEmpty()]
        [string[]] $ArgumentList = @()
    )

    switch ($Name)
    {
        'use' { Use-RubyVersion @ArgumentList }
        'list'
        {
            $splat = @{}
            switch ($ArgumentList)
            {
                default { $splat[$_] = $true }
            }

            Get-RubyVersion @splat
        }
        'install' { Install-RubyVersion @ArgumentList }
        'uninstall' { Uninstall-RubyVersion @ArgumentList }
        'on' { Start-RVM }
        'off' { Stop-RVM }
        default
        {
            Write-Error -Category ObjectNotFound "Command '${Name}' not found."
        }
    }
}

Set-Alias -Name 'rvm' -Value 'Invoke-RVM'
Set-Alias -Name 'ruby' -Value 'Invoke-Ruby'

# startup
[RubyInstallManager] $Script:InstallManager = Resolve-InstallManager -ErrorAction Stop

$ExecutionContext.SessionState.Module.OnRemove = { Stop-RVM }