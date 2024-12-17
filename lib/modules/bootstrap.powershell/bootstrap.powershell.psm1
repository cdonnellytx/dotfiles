#requires -version 7 -modules bootstrap.logging, bootstrap.os, bootstrap.parser, Microsoft.WinGet.Client

using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace Microsoft.WinGet.Client.PSObjects
using namespace Microsoft.WinGet.Client.Engine.PSObjects

[SuppressMessageAttribute('PSAvoidUsingPositionalParameters', 'winget')]
param()

Set-StrictMode -Version Latest

filter flatten
{
    if ($_ -is [object[]])
    {
        $_ | flatten
    }
    else
    {
        $_
    }
}

<#
.PRIVATE
.SYNOPSIS
Wraps winget.exe so we can more easily debug things.
#>
function Invoke-WinGetCli
{
    [OutputType([string[]])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [string] $Command,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [object[]] $Arguments
    )

    [string[]] $FlatArguments = $Arguments | flatten

    if ($DebugPreference)
    {
        Write-Debug "$($PSCmdlet.MyInvocation.MyCommand.Name): winget.exe ${Command} ${FlatArguments}"
    }

    $rawOutput = & winget.exe $Command $FlatArguments 2>&1
    $success = $?

    if ($DebugPreference)
    {
        Write-Debug "$($PSCmdlet.MyInvocation.MyCommand.Name): Success: ${success}`nOutput:`n$($rawOutput | ConvertTo-Json)"
    }

    # WinGet outputs a lot of un-suppressable drawing code (spinners, progress bars) to stdout.
    # However, we don't want that, we just want the meaningful commands.
    $output = [List[string]]::new($rawOutput.Length)
    $messages = [List[string]]::new()
    switch -regex ($rawOutput)
    {
        "^[ \b/|\\-]*$"
        {
            # Skip junk lines that contain spaces and line drawings.
            # Seriously WinGet can we filter those out?
            Write-Debug "[discard] $(ConvertTo-Json $_)"
            continue
        }
        "^Failed in attempting to update the source:"
        {
            Write-Debug "[warn] $_"
            Write-Warning $_
            $output.Add($_)
        }
        "^No installed package found matching input criteria\.$"
        {
            if ($Command -eq 'list')
            {
                # list => package wasn't found.
                # Bail.
                Write-Debug "[actually ok] $_"
                $Success = $true
                $messages.Add($_)
            }
            else
            {
                # fall through
                Write-Debug "[not actually ok] $_"
                $output.Add($_)
            }
        }
        default
        {
            Write-Debug "[default] $_"
            $output.Add($_)
        }
    }

    Write-BootstrapLog @{
        Command = @('winget.exe', $Command) + $FlatArguments
        Success = $success
        RawOutput = $rawOutput
        Output = $output
        Messages = $messages
    }

    Write-Debug "output judgment"
    if (!$success)
    {
        switch ($LASTEXITCODE)
        {
            0x8A15001E
            {
                Write-Error -Category NotImplemented -Message "Installing from the Microsoft Store currently only works for Apps that are `"Free`" and rated `"e`" for everyone."
                return
            }
        }
        Write-Error -Category InvalidArgument -Message "${Command}: ${output}"
        return
    }

    return [string[]] $output
}

class PackageVersion : IComparable
{
    PackageVersion([string] $OriginalVersion)
    {
        $this.OriginalVersion = $OriginalVersion

        [object] $value = $null
        if ([Version]::TryParse($this.OriginalVersion, [ref] $value))
        {
            $this.Major, $this.Minor, $this.Build, $this.Revision = $value.Major, $value.Minor, $value.Build, $value.Revision
        }
        elseif ([SemVer]::TryParse($this.OriginalVersion, [ref] $value))
        {
            # Probably a packageversion in this one, which will show up in semver's PreReleaseLabel.
            switch -regex ($value.PreReleaseLabel)
            {
                '^[0-9]'
                {
                    # starts with numeric, it's a package version
                    $this.PackageVersion = $_
                }
                default
                {
                    $this.PrereleaseLabel = $_
                }
            }

            $this.Major, $this.Minor, $this.Build, $this.BuildLabel = $value.Major, $value.Minor, $value.Patch, $value.BuildLabel
        }
        elseif ([int]::TryParse($this.OriginalVersion, [ref] $value))
        {
            # Single-digit major version
            $this.Major = $value
        }
        else
        {
            # Something else...
            switch -Regex ($this.OriginalVersion)
            {
                # Capture the version digits if those exist.
                '^(?<Version>\d+(\.\d+){1,3})'
                {
                    $value = [Version]::Parse($Matches.Version)
                    $this.Major, $this.Minor, $this.Build, $this.Revision = $value.Major, $value.Minor, $value.Build, $value.Revision
                }

                # Various prerelease flags
                '\bpreview (?<PreReleaseLabel>\S+)'
                {
                    $this.PreReleaseLabel = $Matches.PreReleaseLabel
                }
                '\bbuild (?<BuildLabel>\S.*)'
                {
                    $this.BuildLabel = $Matches.BuildLabel
                }
                # Pythonesque prereleases
                # @see https://www.python.org/download/pre-releases/
                '(?<PrereleaseLabel>(?:[ab]|rc)\d+)$'
                {
                    $this.PreReleaseLabel = $Matches.PreReleaseLabel
                }
            }
        }
    }

    PackageVersion([Version] $Version)
    {
        $this.Major = $Version.Major
        $this.Minor = $Version.Minor
        $this.Build = $Version.Build
        $this.Revision = $Version.Revision
    }

    [int] $Major = -1
    [int] $Minor = -1
    [int] $Build = -1
    [int] $Revision = -1

    [string] $PackageVersion
    [string] $PreReleaseLabel
    [string] $BuildLabel


    [string] $OriginalVersion

    [string] ToString()
    {
        return $this.OriginalVersion
    }

    [bool] Equals([object] $that)
    {
        return $that -is [PackageVersion] -and $this.OriginalVersion -ceq $that.OriginalVersion
    }

    [int] GetHashCode()
    {
        return $this.OriginalVersion.GetHashCode()
    }

    [int] CompareTo([object] $that)
    {
        if ($null -eq $that)
        {
            return 1;
        }

        [int] $diff = $this.Major.CompareTo($that.Major);
        if ($diff -ne 0) { return $diff; }

        $diff = $this.Minor.CompareTo($that.Minor);
        if ($diff -ne 0) { return $diff; }

        $diff = $this.Build.CompareTo($that.Build);
        if ($diff -ne 0) { return $diff; }

        $diff = $this.Revision.CompareTo($that.Revision);
        if ($diff -ne 0) { return $diff; }

        $diff = [StringComparer]::OrdinalIgnoreCase.Compare($this.PrereleaseLabel, $that.PrereleaseLabel);
        if ($diff -ne 0) { return $diff; }

        # For sorts only
        return [StringComparer]::OrdinalIgnoreCase.Compare($this.BuildLabel, $that.BuildLabel);
    }
}

<#
.SYNOPSIS
Searches for a package available for install using the `Find-WinGetPackage` command.

.NOTES
Values are sorted by version descending (with version properly parsed).
#>
function Find-ViaWinGet
{
    [CmdletBinding(DefaultParameterSetName = 'Id')]
    [OutputType([PSCustomObject])]
    param
    (
        # Filter results by id
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Id', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        # Filter results by name
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Name', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Name,

        # Filter results by moniker
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Moniker', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Moniker,

        # Filter results by tag
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Tag', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Tag,

        # Filter results by command
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Command', ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('cmd')]
        [string] $Command,

        # The source to install via.  Default is explicitly 'winget'.
        [Parameter(ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Source = 'winget',

        # When true, include prerelease versions.
        [Parameter()]
        [switch] $AllowPrerelease
    )

    process
    {
        [string] $description = switch ($PSCmdlet.ParameterSetName)
        {
            'Id' { "id: ${Id}" }
            'Name' { "name: ${Name}" }
            'Moniker' { "moniker: ${Moniker}" }
            'Command' { "command: ${Command}" }
            'Tag' { "tag: ${Tag}" }
            default
            {
                Write-Error -Category NotImplemented "For parameter set '${_}'"
                return
            }
        }
        Write-Verbose "Find via WinGet (${description})"

        # Replace version with PackageVersion, Sort output by version descending.
        Microsoft.WinGet.Client\Find-WinGetPackage @PSBoundParameters |
            Select-Object -ExcludeProperty 'Version' -Property *,
            @{ Name = 'Version'; Expression = { [PackageVersion] $_.Version } },
            @{ Name = 'RawVersion'; Expression = 'Version' } |
            Where-Object { $AllowPrerelease -or !$_.Version.PreReleaseLabel } |
            Sort-Object -Descending -Property Version
    }
}

<#
.SYNOPSIS
Install a package via PSResource if not already installed.
#>
function Install-ViaPSResourceGet
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType('Microsoft.PowerShell.PSResourceGet.UtilClasses.PSResourceInfo')]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [PowerShellModuleInfo] $InputObject,

        # Force the installer to run.
        [Parameter()]
        [switch] $Force,

        # When true, returns the result state.
        [Parameter()]
        [switch] $PassThru
    )

    process
    {
        #region Arguments

        if ($DebugPreference)
        {
            Write-Debug "$($PSCmdlet.MyInvocation.MyCommand.Name): InputObject: $($InputObject | Out-String)"
        }

        # #endregion Arguments

        Invoke-Operation -Name "Install module '$($InputObject.Name)'" -ScriptBlock {
            if (!$_.Condition)
            {
                Skip-Operation $_.SkipMessage
            }

            if ($installedModule = Get-PSResource -Name $_.Name -ErrorAction Ignore)
            {
                Skip-Operation "v$($installedModule.Version) was already installed"
                return
            }

            Install-PSResource -Name $_.Name -PassThru:$PassThru
        }
    }
}

class PowerShellModuleInfo
{
    [string] $Name
    [bool] $Condition = $true

    # The optional skip message.
    [string] $SkipMessage = $null

    # hashtable to object constructor
    PowerShellModuleInfo()
    {
    }

    # string to object constructor
    PowerShellModuleInfo([string] $Name)
    {
        $this.Name = $Name
    }

    [string] ToString()
    {
        return $this.Name
    }
}
