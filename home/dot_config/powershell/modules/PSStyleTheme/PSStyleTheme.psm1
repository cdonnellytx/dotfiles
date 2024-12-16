#requires -module PSReadLine
using namespace System
using namespace System.Collections.Generic
using namespace System.Diagnostics.CodeAnalysis
using namespace System.Globalization
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Management.Automation.Host
using namespace System.Text
using namespace System.Text.Json
using namespace Microsoft.PowerShell

[SuppressMessageAttribute('PSAvoidGlobalVars', '')]
param
(
    # The path to the config (default $PROFILE/../PSStyleTheme.psd1).
    [string] $ConfigPath = [Path]::Combine([Path]::GetDirectoryName($global:PROFILE), 'PSStyleTheme.psd1')
)

Push-Stopwatch 'psm1'
Push-Stopwatch "Classes and Functions"
Set-StrictMode -Version Latest

#
# Module state
#

class UserConfiguration
{
    # The path to the theme.
    [string] $Theme

    static [UserConfiguration] FromFile([string] $LiteralPath)
    {
        return [UserConfiguration] (Import-PowerShellDataFile -LiteralPath $LiteralPath)
    }

    [void] Save([string] $LiteralPath)
    {
        [File]::WriteAllText($LiteralPath, $this.ToPowerShellDataString())
    }

    [string] ToPowerShellDataString()
    {
        # There isn't an Export-PowerShellDataFile.  I mean seriously guys?!

        $sb = [StringBuilder]::new()
        $sb.AppendLine('@{')
        if ($this.Theme)
        {
            $sb.AppendFormat('  Theme = "{0}"', ($this.Theme -creplace '(["`])', '`${1}'))
            $sb.AppendLine()
        }
        $sb.AppendLine('}')

        return $sb.ToString()
    }
}

<#
.SYNOPSIS
Adapter base class
#>
class ColorAdapter
{
    [void] Apply([PSStyleTheme] $theme)
    {
        throw [NotImplementedException]::new("Method not implemented: $($this.GetType().FullName)].Apply(PSStyleTheme)")
    }
}

<#
.SYNOPSIS
Helper type for reading in arbitrary colors into ANSI escape sequences.
#>
<# static #> class AnsiEscapeSequence
{
    static [string] ToVtEscapeSequence([string] $color, [bool] $background)
    {
        if ($Color -clike "`u{001b}*m")
        {
            # It's already an ANSI sequence.
            return $Color
        }

        if ($Color -imatch "^#?(?<R>[0-9a-f][0-9a-f])(?<G>[0-9a-f][0-9a-f])(?<B>[0-9a-f][0-9a-f])$")
        {
            # Convert to RgbColor, then to ANSI sequence.
            $code = if ($background) { 48 } else { 38 }
            ($r, $g, $b) = $matches['r'], $matches['g'], $matches['b'] | ForEach-Object { [int]::Parse($_, [System.Globalization.NumberStyles]::HexNumber) }

            return "`u{001B}[{0:n0};2;{1:n0};{2:n0};{3:n0}m" -f $code, $r, $g, $b
        }

        throw [ArgumentOutOfRangeException]::new("color", $color, "Cannot convert color to ANSI sequence")
    }

    static [string] $Reset = "`e[0m"
}

<#
.SYNOPSIS
PSReadLine color set.
#>
class PSReadLineColorSet
{
    [string] $Command
    [string] $Comment
    [string] $ContinuationPrompt
    [string] $Default
    [string] $Emphasis
    [string] $Error
    [string] $InlinePrediction
    [string] $Keyword
    [string] $ListPrediction
    [string] $ListPredictionSelected
    # @since PSReadLine 2.3
    [string] $ListPredictionTooltip
    [string] $Member
    [string] $Number
    [string] $Operator
    [string] $Parameter
    [string] $Selection
    [string] $String
    [string] $Type
    [string] $Variable
}

class PSStyleFormatting
{
    [string] $FormatAccent
    [string] $TableHeader
    [string] $ErrorAccent
    [string] $Error
    [string] $Warning
    [string] $Verbose
    [string] $Debug

    [void] ApplyTo([PSStyle+FormattingData] $Formatting)
    {
        $Formatting.FormatAccent = $this.FormatAccent
        $Formatting.TableHeader = $this.TableHeader
        $Formatting.ErrorAccent = $this.ErrorAccent
        $Formatting.Error = $this.Error
        $Formatting.Warning = $this.Warning
        $Formatting.Verbose = $this.Verbose
        $Formatting.Debug = $this.Debug
    }
}

class PSStyleProgress
{
    [string] $Style
    [int] $MaxWidth
    [ProgressView] $View = [ProgressView]::Minimal
    [bool] $UseOSCIndicator

    [void] ApplyTo([PSStyle+ProgressConfiguration] $Progress)
    {
        $Progress.Style = $this.Style
        $Progress.MaxWidth = $this.MaxWidth
        $Progress.View = $this.View
        $Progress.UseOSCIndicator = $this.UseOSCIndicator
    }
}

class PSStyleColorSet
{
    [OutputRendering] $OutputRendering
    [PSStyleFormatting] $Formatting = [PSStyleFormatting]::new()
    [PSStyleProgress] $Progress = [PSStyleProgress]::new()
    [PSStyleFileInfo] $FileInfo = [PSStyleFileInfo]::new()

    [void] ApplyTo([PSStyle] $style)
    {
        $this.Formatting.ApplyTo($style.Formatting)
        $this.Progress.ApplyTo($style.Progress)
    }
}

class PSStyleFileInfo
{
    [string] $Directory
    [string] $SymbolicLink
    [string] $Executable
    [Hashtable] $Extension

    hidden [string] FormatExtension()
    {
        # Stolen from `Get-FormatData $PSStyle.FileInfo.gettype().FullName`
        $sb = [System.Text.StringBuilder]::new()
        $maxKeyLength = 0
        foreach ($key in $this.Extension.Keys)
        {
            if ($key.Length -gt $maxKeyLength) {
                $maxKeyLength = $key.Length
            }
        }

        foreach ($key in $this.Extension.Keys) {
            $null = $sb.Append($key.PadRight($maxKeyLength))
            $null = $sb.Append(' = "')
            $null = $sb.Append($this.Extension[$key])
            $null = $sb.Append($this.Extension[$key].Replace("`e",'`e'))
            $null = $sb.Append([AnsiEscapeSequence]::Reset)
            $null = $sb.Append('"')
            $null = $sb.Append([Environment]::NewLine)
        }

        return $sb.ToString()
    }
}

class PSStyleTheme
{
    hidden static [PSMemberInfo[]] $_PSStandardMembers = @(
        [PSPropertySet]::new(
            'DefaultDisplayProperty',
            [string[]] @('Name')
        ),
        [PSPropertySet]::new(
            'DefaultKeyPropertySet',
            [string[]] @('Name')
        ),
        [PSPropertySet]::new(
            'DefaultDisplayPropertySet',
            [string[]] @('Name', 'Description')
        )
    )

    [string] $Name
    [string] $Description
    [string] $Repository

    # Color sets
    [PSReadLineColorSet] $PSReadLine
    [PSStyleColorSet] $PSStyle

    [string] $Path

    PSStyleTheme()
    {
        $this | Add-Member -MemberType MemberSet -Name PSStandardMembers -Value ([PSStyleTheme]::_PSStandardMembers)
    }

    [string] ToString()
    {
        return $this.name
    }
}

<#
.SYNOPSIS
Our console theme.

.NOTES
Note that we need to be aware of console background/foreground color, for multiple reasons:
  1. ConHost.exe (at least in Windows 8.0) *looks* White-on-Blue, but is really a redefined DarkYellow-on-Magenta.
     This can be detected by the $Host.UI.RawUI object.
     @see https://social.technet.microsoft.com/Forums/windowsserver/en-US/4b43f071-abf5-4a65-9048-82d474473a8e/how-can-i-set-the-powershell-console-background-color-not-the-text-background-color?forum=winserverpowershell
  2. NuGet Package Manager will be colored based on the user's Visual Studio theme: either a light gray (Blue, Light) or dark gray (Dark).
     However, this cannot be detected via the RawUI -- it only returns -1.
  3. PowerShell ISE has its own theming.

#>
class ThemeManager
{
    # The loaded adapters.
    hidden [ColorAdapter[]] $_adapters

    # The path to the config.
    hidden [string] $_configPath

    # The current user configuration.
    hidden [UserConfiguration] $_userConfig

    hidden [Dictionary[string, PSStyleTheme]] $_themeCache = $null
    hidden [Dictionary[string, ErrorRecord]] $_themeErrorCache = $null

    hidden [PSStyleTheme] $_currentTheme = $($this | Add-Member ScriptProperty 'CurrentTheme' `
            <# get #> -Value { return $this._currentTheme } `
            <# set #> -SecondValue {
            param ([PSStyleTheme] $value)
            if ($value -ne $this._currentTheme)
            {
                $this._currentTheme = $value
                $this._userConfig.Theme = $value.Path
                $this.OnCurrentThemeChanged($value)
            }
        }
    )

    hidden [Hashtable] ReadJsonContent([string] $Path)
    {
        return ConvertFrom-Json -AsHashtable -InputObject ([File]::ReadAllText($Path))
    }

    [void] LoadConfiguration()
    {
        $this._userConfig = if ([File]::Exists($this._configPath))
        {
            [UserConfiguration]::FromFile($this._configPath)
        }
        else
        {
            [UserConfiguration]::new()
        }

        $this.OnUserConfigChanged()
    }

    [void] SaveConfiguration()
    {
        $this._userConfig.Save($this._configPath)
    }

    ThemeManager([string] $ConfigPath, [ColorAdapter[]] $Adapters)
    {
        $this._configPath = $ConfigPath
        $this._adapters = $Adapters

        $this.LoadConfiguration()
    }

    hidden [PSStyleTheme] ResolveUserConfigTheme()
    {
        if ($this._userConfig.Theme)
        {
            return $this.GetTheme($this._userConfig.Theme)
        }

        return $null
    }

    hidden [void] OnCurrentThemeChanged([PSStyleTheme] $theme)
    {
        Push-Stopwatch '.OnCurrentThemeChanged'
        $this.ApplyColors($theme)
        Pop-Stopwatch
    }

    hidden [void] OnUserConfigChanged()
    {
        Push-Stopwatch '.OnUserConfigChanged'
        Push-Stopwatch 'ResolveUserConfigTheme'
        try
        {
            $theme = $this.ResolveUserConfigTheme()
        }
        catch
        {
            Write-Error "Cannot resolve theme: $_"
            $theme = $null
        }
        finally
        {
            Pop-Stopwatch
        }

        $this._currentTheme = $theme
        $this.OnCurrentThemeChanged($theme)
        Pop-Stopwatch
    }

    hidden [PSStyleTheme] ReadTheme([string] $literalPath)
    {
        Push-Stopwatch ".ReadTheme $literalPath"
        try
        {
            Push-Stopwatch ".ReadJsonContent"
            [hashtable] $themeData = $this.ReadJsonContent($literalPath)
            Pop-Stopwatch
            Push-Stopwatch "(PSStyleTheme) themeData"
            [PSStyleTheme] $theme = $themeData
            Pop-Stopwatch
            Push-Stopwatch "PSStyleTheme::set_Path(value)"
            $theme.Path = $literalPath
            Pop-Stopwatch
            Push-Stopwatch 'PSStyleTheme::get_PSStyle()'
            if ($null -eq $theme.PSStyle)
            {
                Push-Stopwatch 'PSStyleColorSet::new()'
                $theme.PSStyle = [PSStyleColorSet]::new()
                Pop-Stopwatch
            }
            Pop-Stopwatch
            return $theme
        }
        finally
        {
            Pop-Stopwatch
        }
    }

    hidden [void] LoadThemes()
    {
        $this._themeCache = [Dictionary[string, PSStyleTheme]]::new(10, [StringComparer]::OrdinalIgnoreCase)
        $this._themeErrorCache = [Dictionary[string, ErrorRecord]]::new(10, [StringComparer]::OrdinalIgnoreCase)

        [DirectoryInfo[]] $ThemeDirs = [Path]::Combine([Path]::GetDirectoryName($this._configPath), 'PSStyleThemes'),
        [Path]::Combine($PSScriptRoot, 'themes')

        foreach ($ThemeDir in $ThemeDirs)
        {
            if (!$ThemeDir.Exists) { continue }
            foreach ($ThemeFile in $ThemeDir.EnumerateFiles('*.theme.json'))
            {
                try
                {
                    $theme = $this.ReadTheme($ThemeFile)
                    $this._themeCache.Add($theme.Name, $theme)
                }
                catch
                {
                    $this._themeErrorCache.Add($ThemeFile, $_)
                    continue
                }
            }
        }
    }

    hidden [void] LoadThemesIfNeeded()
    {
        if ($null -eq $this._themeCache)
        {
            $this.LoadThemes()
        }
    }

    [PSStyleTheme] GetThemeByName([string] $Name)
    {
        Push-Stopwatch ".GetThemeByName $Name"
        try
        {
            $this.LoadThemesIfNeeded()
            [ref] $ref = $null
            if ($this._themeCache.TryGetValue($Name, $ref))
            {
                return $ref.Value
            }


            $errKeys = $this._themeErrorCache.Keys | Where-Object { $_ -like ('*{0}.theme.json' -f $Name) }
            if ($errKeys)
            {
                $e = $this._themeErrorCache[$errKeys]
                throw [InvalidOperationException]::new("Theme '${Name}' failed to load.  ${e}", $e.Exception)
            }
            return $null
        }
        finally
        {
            Pop-Stopwatch
        }
    }

    [PSStyleTheme] GetTheme([string] $NameOrPath)
    {
        Push-Stopwatch ".GetTheme $NameorPath"
        try
        {
            switch -wildcard ($NameOrPath)
            {
                '*.theme.json'
                {
                    return $this.ReadTheme($_)
                }
                # default: fall through (MSCRAP: switch default)
            }

            return $this.GetThemeByName($NameOrPath)
        }
        finally
        {
            Pop-Stopwatch
        }
    }

    [Dictionary[string, ErrorRecord]]  GetThemeErrors()
    {
        $this.LoadThemesIfNeeded()
        return $this._themeErrorCache
    }

    [PSStyleTheme[]] GetThemes()
    {
        Write-Debug "GetThemes()"
        $this.LoadThemesIfNeeded()
        return $this._themeCache.Values
    }

    <#
    .SYNOPSIS
    Apply the theme.
    #>
    hidden [void] ApplyColors([PSStyleTheme] $theme)
    {
        Push-Stopwatch '.ApplyColors'
        # FIXME
        if ($null -eq $theme)
        {
            return
        }

        foreach ($adapter in $this._adapters)
        {
            $adapter.Apply($theme)
        }
        Pop-Stopwatch
    }
}

<#
.SYNOPSIS
Base class for applying colors to PSReadLine.
#>
class PSReadLineColorAdapter : ColorAdapter
{
    static [PSReadLineColorAdapter] GetInstance()
    {
        Push-Stopwatch 'PSReadLineColorAdapter::GetInstance()'
        try
        {
            if ($PSReadLine = Get-Module -Name PSReadLine -ErrorAction Ignore)
            {
                # Threshold for latest (one version check) vs. fallback (runtime version checks)
                if ($PSReadLine.Version -ge '2.3')
                {
                    return [PSReadLineLatestColorAdapter]::new()
                }
                else
                {
                    return [PSReadLineFallbackColorAdapter]::new($PSReadLine.Version)
                }
            }

            return $null
        }
        finally
        {
            Pop-Stopwatch
        }
    }

    [void] ApplyTo([PSConsoleReadLineOptions] $options, [PSReadLineColorSet] $theme)
    {
        throw [NotImplementedException]::new("Method not implemented: $($this.GetType().FullName)].ApplyTo(Hashtable, PSReadLineColorSet)")
    }

    [void] Apply([PSStyleTheme] $theme)
    {
        Push-Stopwatch 'PSReadLineColorAdapter.Apply'
        try
        {
            Push-Stopwatch 'PSConsoleReadLine::GetOptions()'
            $options = [PSConsoleReadLine]::GetOptions()
            Pop-Stopwatch
            Push-Stopwatch 'PSReadLineColorAdapter.ApplyTo'
            $this.ApplyTo($options, $theme.PSReadLine)
            Pop-Stopwatch
        }
        finally
        {
            Pop-Stopwatch
        }
    }
}

<#
.SYNOPSIS
Allows for older versions of PSReadLine, but is slower.
Supports PSReadLine 2.0 and later.
#>
class PSReadLineFallbackColorAdapter : PSReadLineColorAdapter
{
    [Version] $Version

    PSReadLineFallbackColorAdapter([Version] $version)
    {
        $this.Version = $version
    }

    [void] ApplyTo([PSConsoleReadLineOptions] $options, [PSReadLineColorSet] $theme)
    {
        # 2.0
        if ($this.Version -lt '2.0') { return }
        $options.CommandColor = $theme.Command
        $options.CommentColor = $theme.Comment
        $options.ContinuationPromptColor = $theme.ContinuationPrompt
        $options.DefaultTokenColor = $theme.Default
        $options.EmphasisColor = $theme.Emphasis
        $options.ErrorColor = $theme.Error
        $options.KeywordColor = $theme.Keyword
        $options.MemberColor = $theme.Member
        $options.NumberColor = $theme.Number
        $options.OperatorColor = $theme.Operator
        $options.ParameterColor = $theme.Parameter
        $options.SelectionColor = $theme.Selection
        $options.StringColor = $theme.String
        $options.TypeColor = $theme.Type
        $options.VariableColor = $theme.Variable

        # 2.1
        if ($this.Version -lt '2.1') { return }
        $options.InlinePredictionColor = $theme.InlinePrediction

        # 2.2
        if ($this.Version -lt '2.2') { return }
        $options.ListPredictionColor = $theme.ListPrediction
        $options.ListPredictionSelectedColor = $theme.ListPredictionSelected

        # 2.3
        if ($this.Version -lt '2.3') { return }
        $options.ListPredictionTooltipColor = $theme.ListPredictionTooltip
    }

}

<#
.SYNOPSIS
Assumes "latest" PSReadLine and just sets colors at the expense of slower checking.
Supports PSReadLine 2.3 and later.
.NOTES
Microsoft keeps adding colors, so :shrug:
.LINK
https://devblogs.microsoft.com/powershell/announcing-psreadline-2-1-with-predictive-intellisense/
#>
class PSReadLineLatestColorAdapter : PSReadLineColorAdapter
{
    [void] ApplyTo([PSConsoleReadLineOptions] $options, [PSReadLineColorSet] $theme)
    {
        # 2.0
        $options.CommandColor = $theme.Command
        $options.CommentColor = $theme.Comment
        $options.ContinuationPromptColor = $theme.ContinuationPrompt
        $options.DefaultTokenColor = $theme.Default
        $options.EmphasisColor = $theme.Emphasis
        $options.ErrorColor = $theme.Error
        $options.KeywordColor = $theme.Keyword
        $options.MemberColor = $theme.Member
        $options.NumberColor = $theme.Number
        $options.OperatorColor = $theme.Operator
        $options.ParameterColor = $theme.Parameter
        $options.SelectionColor = $theme.Selection
        $options.StringColor = $theme.String
        $options.TypeColor = $theme.Type
        $options.VariableColor = $theme.Variable

        # 2.1
        $options.InlinePredictionColor = $theme.InlinePrediction

        # 2.2
        $options.ListPredictionColor = $theme.ListPrediction
        $options.ListPredictionSelectedColor = $theme.ListPredictionSelected

        # 2.3
        $options.ListPredictionTooltipColor = $theme.ListPredictionTooltip
    }
}

<#
.SYNOPSIS
Applies color to PSStyle.
#>
class PSStyleColorAdapter : ColorAdapter
{
    # The host
    hidden [PSStyle] $_style

    PSStyleColorAdapter()
    {
        $this._style = $Global:PSStyle
    }

    PSStyleColorAdapter([PSStyle] $style)
    {
        $this._style = $style
    }

    [void] Apply([PSStyleTheme] $theme)
    {
        Push-Stopwatch 'PSStyleColorAdapter.Apply'
        $theme.PSStyle.ApplyTo($this._style)
        Pop-Stopwatch
    }
}

<#
.SYNOPSIS
Writes out the PSStyleTheme information.
#>
function Write-PSStyleTheme
{
    [CmdletBinding()]
    param
    (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [PSStyleTheme] $Theme
    )

    process
    {
        $hash = [ordered] @{}
        if ($Theme.PSReadLine)
        {
            $Theme.PSReadLine.PSObject.Properties | ForEach-Object {
                $hash.Add(
                    'PSReadLine.{0}' -f $_.Name,
                    "{0:swatch}" -f $_.Value
                )
            }
        }

        if ($Theme.PSStyle)
        {
            if ($Theme.PSStyle.Formatting)
            {
                $Theme.PSStyle.Formatting.PSObject.Properties | ForEach-Object {
                    $hash.Add(
                        'PSStyle.Formatting.{0}' -f $_.Name,
                        "{0:swatch}" -f $_.Value
                    )
                }
            }
            if ($Theme.PSStyle.Progress)
            {
                $hash.Add('PSStyle.Progress.Style', $Theme.PSStyle.Progress.Style.ToSwatchString())
                $hash.Add('PSStyle.Progress.MaxWidth', $Theme.PSStyle.Progress.MaxWidth)
                $hash.Add('PSStyle.Progress.View', $Theme.PSStyle.Progress.View)
                $hash.Add('PSStyle.Progress.UseOSCIndicator', $Theme.PSStyle.Progress.UseOSCIndicator)
            }

            if ($Theme.PSStyle.FileInfo)
            {
                $hash.Add('PSStyle.FileInfo.Directory', $Theme.PSStyle.FileInfo.Directory.ToSwatchString())
                $hash.Add('PSStyle.FileInfo.SymbolicLink', $Theme.PSStyle.FileInfo.SymbolicLink.ToSwatchString())
                $hash.Add('PSStyle.FileInfo.Executable', $Theme.PSStyle.FileInfo.Executable.ToSwatchString())
                $hash.Add('PSStyle.FileInfo.Extension', $Theme.PSStyle.FileInfo.FormatExtension())
            }
        }

        return [PSCustomObject] $hash
    }
}

function Get-PSStyleTheme
{
    [CmdletBinding(DefaultParameterSetName = 'Current')]
    [OutputType([PSStyleTheme])]
    param
    (
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'Name')]
        [string] $Name,

        [Parameter(Mandatory = $false, ParameterSetName = 'ListAvailable')]
        [switch] $ListAvailable
    )

    Write-Debug "Get-PSStyleTheme ParameterSetName=$($PSCmdlet.ParameterSetName)"
    switch ($PSCmdlet.ParameterSetName)
    {
        'Current'
        {
            $ThemeManager.CurrentTheme
        }

        'Name'
        {
            $ThemeManager.GetThemeByName($Name)
        }
        'ListAvailable'
        {
            if ($ListAvailable)
            {
                foreach ($entry in $ThemeManager.GetThemeErrors().GetEnumerator())
                {
                    Write-Error ("For {0}: {1}" -f $entry.Key, $entry.Value)
                }
                $ThemeManager.GetThemes()
            }
        }
    }
}

function Set-PSStyleTheme
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The name or path.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Name
    )

    $Theme = $ThemeManager.GetTheme($Name)

    if (!$Theme)
    {
        Write-Error -Category ObjectNotFound -Message "Theme not found: '${Name}'"
        return
    }

    if ($PSCmdlet.ShouldProcess("Theme: ${Theme}, Path: $($Theme.Path)", "Set PSStyle Theme"))
    {
        $ThemeManager.CurrentTheme = $Theme
        $ThemeManager.SaveConfiguration()
    }
}

function Show-PSStyleTheme
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSStyleTheme])]
    param
    (
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'Name')]
        [string] $Name,

        [Parameter(Mandatory = $false, ParameterSetName = 'Default')]
        [switch] $ListAvailable
    )

    Get-PSStyleTheme @PSBoundParameters | Write-PSStyleTheme
}
Pop-Stopwatch

#
# Main
#
Push-Stopwatch -Name 'ColorAdapters[]::new()'
$Adapters = @(
    [PSStyleColorAdapter]::new($PSStyle),
    [PSReadLineColorAdapter]::GetInstance()
)
Pop-Stopwatch

Push-Stopwatch -Name 'ThemeManager::new()'
$Script:ThemeManager = [ThemeManager]::new($ConfigPath, $Adapters)
Pop-Stopwatch
Push-Stopwatch -Name 'Assign Global'
$Global:PSStyleThemeManager = $Script:ThemeManager
Pop-Stopwatch
Pop-Stopwatch