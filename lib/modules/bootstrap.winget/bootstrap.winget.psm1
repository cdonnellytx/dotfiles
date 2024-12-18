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
Install a package via WinGet.

.NOTES
Install is always exact.

MSCRAP: WinGet 1.8.1911 Install-WinGetPackage has several issues:
- It does not honor -WhatIf
- It does not print verbose install info
- It _always_ installs even if the package is already installed (or not)
- It explicitly rejects the `-Debug` parameter, stating "Debug parameter not supported"
#>
function Install-ViaWinGet
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    [OutputType('Microsoft.WinGet.Client.Engine.PSObjects.PSInstalledCatalogPackage')]
    [OutputType('Microsoft.WinGet.Client.Engine.PSObjects.PSInstallResult')]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [WinGetItem] $InputObject,

        # Force the installer to run.
        [Parameter()]
        [switch] $Force
    )

    process
    {
        if (!$PSCmdlet.ShouldProcess($InputObject.ToString(), 'Install via WinGet'))
        {
            return
        }

        Invoke-Operation -ErrorAction Stop -Name "Installing ${InputObject}" -ArgumentList $Force -ScriptBlock {
            param($Force)

            if (!(Resolve-Condition $InputObject.Condition))
            {
                return Skip-Operation $InputObject.SkipMessage
            }

            # WinGet install wrapper.
            # Be warned that `winget.exe install` (and Install-WinGetPackage) always installs certain apps, like Dropbox, so we have to test for its existence first.
            if (!$Force -and ($result = $InputObject | Get-WinGetPackage -ErrorAction:Stop))
            {
                return Skip-Operation "v$($result.InstalledVersion) already installed"
            }

            $result = $InputObject | Microsoft.WinGet.Client\Install-WinGetPackage

            switch ($result.Status)
            {
                # We're good.
                'Ok'
                {
                    return
                }

                'NoApplicableInstallers'
                {
                    Write-Error -Category NotEnabled -Message "Scope '$($InputObject.Scope)' is not supported for this application." 2>&1 | Exit-Operation
                }

                'InstallError'
                {
                    Write-Error -Category InvalidResult -Message "Install failed: $($result.ExtendedErrorCode)" 2>&1 | Exit-Operation
                }

                default
                {
                    switch ($result.ExtendedErrorCode.ErrorCode)
                    {
                        0x8A15001E
                        {
                            # MSCRAP: The "msstore" source currently only works for Apps that are "Free" and rated "e" for everyone.
                            # https://github.com/microsoft/winget-cli/issues/2052#issuecomment-1516664318
                            switch ($InputObject.Source)
                            {
                                'msstore'
                                {
                                    Start-Process "ms-windows-store://pdp/?ProductId=$($InputObject.Id)"
                                    Write-Error -Category NotImplemented -Message "Installing from the Microsoft Store currently only works for Apps that are `"Free`" and rated `"e`" for everyone." 2>&1 | Exit-Operation
                                    return
                                }

                                # default: fall through.
                            }
                        }
                    }

                    Write-Error -Category InvalidResult -Message ('winget exited with code {0:X8}: {1}' -f $_, $result.ExtendedErrorCode) 2>&1 | Exit-Operation
                }
            }
        }
    }
}

<#
.SYNOPSIS
Pins the matching WinGet package.
#>
function Lock-WinGet
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param
    (
        # The ID of the package to pin.  Must be exact.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string] $Id,

        # Version to which to pin the package. The wildcard '*' can be used as the last version part
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string] $Version,

        # Direct run the command and continue with non security related issues
        [Parameter()]
        [switch] $Force,

        # Block from upgrading until the pin is removed, preventing override arguments
        [Parameter()]
        [switch] $Blocking,

        # Pin a specific installed version
        [Parameter()]
        [switch] $Installed
    )

    begin
    {
        #region Arguments

        [string[]] $pinAddArguments = @()

        if ($Version)
        {
            $pinAddArguments += '--version', $Version
        }

        if ($Force)
        {
            $pinAddArguments += '--force'
        }

        if ($Blocking)
        {
            $pinAddArguments += '--blocking'
        }

        if ($Installed)
        {
            $pinAddArguments += '--installed'
        }

        $pinAddArguments += @(
            '--disable-interactivity',
            '--accept-source-agreements'
        )

        #endregion Arguments
    }

    process
    {
        $GetParams = ([hashtable] $PSBoundParameters).Clone()
        $GetParams.Remove('WhatIf')
        $GetParams.Remove('Force')
        $GetParams.Remove('Version')
        $GetParams.Remove('Blocking')
        $GetParams.Remove('Installed')

        Get-WinGetPackage -Count 1 -MatchOption:EqualsCaseInsensitive @GetParams | ForEach-Object {
            if ($PSCmdlet.ShouldProcess("Id: $($_.Id), arguments: $pinAddArguments", 'Pin WinGet package'))
            {
                switch -Regex (Invoke-WinGetCli pin add --id $_.Id @pinAddArguments)
                {
                    "^Found (?<Description>.+) \[(\w+\.\w+)]$"
                    {
                        # Found the package, good...
                        Write-Debug $_
                    }
                    "^Pin added successfully$"
                    {
                        # Success!
                        Write-Debug $_
                    }
                    "^There is already a pin\b"
                    {
                        Write-Information -Tags 'winget' -MessageData $_
                    }

                    default
                    {
                        Write-Warning $_
                    }

                }
            }
        }
    }
}

class WinGetItem
{
    [string] $Id
    [string] $Source = 'winget'
    [PSPackageInstallScope] $Scope = 'UserOrUnknown'

    # Specify the match option for a WinGet package query. This parameter accepts the following values:
    #   - `Equals`
    #   - `EqualsCaseInsensitive`
    #   - `StartsWithCaseInsensitive`
    #   - `ContainsCaseInsensitive`
    [PSPackageFieldMatchOption] $MatchOption = [PSPackageFieldMatchOption]::Equals

    # The maximum number of items to return.  Assumes exact match is desired.
    [int] $Count = 1

    # An optional condition (bool or scriptblock)
    $Condition

    # The optional skip message.
    [string] $SkipMessage = $null

    # The mode of install.
    #   - `Default`: show the installer (noninteractive)
    #   - `Interactive`: show the installer (interactive)
    #   - `Silent`: do not show the installer.  This is **our** default.
    #
    # Improperly-scripted packages may ignore this, however.
    [PSPackageInstallMode] $Mode = [PSPackageInstallMode]::Silent

    # A name for documentation purposes.  Not WinGetPackage name.
    [string] $Description

    # Zero-arg cast constructor
    WinGetItem() {}

    WinGetItem([string] $Id)
    {
        $this.Id = $Id
    }

    WinGetItem([string] $Id, [string] $Description)
    {
        $this.Id = $Id
        $this.Description = $Description
    }

    [string] ToString()
    {
        if ($this.Description)
        {
            return '"{0}" (id: {1})' -f $this.Description, $this.Id
        }
        return $this.Id
    }
}
