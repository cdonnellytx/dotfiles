using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Globalization
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Reflection
using namespace System.Text
using namespace System.Xml
using namespace System.Xml.Linq

using module posh-projectsystem
using module ../posh-projectsystem/SemanticVersion/SemanticVersion.psd1

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleSyntax', '', Target = '7.0')]
param()

Set-StrictMode -Version Latest

$FallbackMap = [Dictionary[Framework, HashSet[Framework]]]::new()

$DotnetVersion = [System.Environment]::Version
$DefaultFramework = 'net{0}.{1}' -f $DotnetVersion.Major, $DotnetVersion.Minor

<#
.SYNOPSIS
Lists local NuGet resources such as http requests cache, packages folder, plugin operations cache  or machine-wide global packages folder.
#>
function Get-NuGetCacheLocation
{
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    [OutputType([PSCustomObject])]
    param
    (
        [Parameter(Position = 0, Mandatory, ParameterSetName = 'Name')]
        [ValidateSet('global-packages', 'http-cache', 'plugins-cache', 'temp')]

        [string] $Name,

        [Parameter(ParameterSetName = 'Name')]
        [switch] $AsObject
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        'Default' { $Name = 'all'; $AsObject = $true }
        'Name' { }
    }

    [string[]] $output = dotnet nuget locals --list $Name
    if (!$?)
    {
        Write-Error -Category InvalidResult -Message (Out-String -InputObject $output)
        return
    }

    if ($AsObject)
    {
        $hash = @{}
        foreach ($line in $output)
        {
            $hash.Add.Invoke(($line -csplit ':\s*', 2))
        }

        return [PSCustomObject] $hash
    }
    else
    {
        ($output -csplit ':\s*', 2)[1]
    }
}

function Register-Framework
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Framework] $Framework,

        [Parameter(Position = 1)]
        [Framework[]] $Fallbacks = @(),

        [switch] $Recurse
    )

    $FallbackMap[$Framework] += $Fallbacks | ForEach-Object {
        $_
        if ($Recurse -and $FallbackMap.ContainsKey($_))
        {
            $FallbackMap[$_]
        }
    }
}

class Framework : IComparable
{
    [string] $Family

    [SemanticVersion] $Version

    [string[]] $Options

    hidden [string] $OriginalValue

    [string] $Value

    Framework([string] $framework)
    {
        $this.OriginalValue = $framework

        [string[]] $parts = $framework -split '-', 2
        switch ($Parts.Length)
        {
            0 { throw [ArgumentNullException]::new('framework') }
            1 { } # empty
            default
            {
                $this.Options = $parts[1].Split('+')
            }
        }

        switch -regex ($Parts[0].TrimStart('.'))
        {
            '^net(?<Major>[1-4])(?<Minor>[05-9])(?<Patch>\d)$'
            {
                # net452
                $this.Family = 'netframework'
                $this.Version = [SemanticVersion]::new([int] $Matches.Major, [int] $Matches.Minor, [int] $Matches.Patch)
                break
            }
            '^net(?<Major>[1-4])(?<Minor>\d)$'
            {
                # net45
                $this.Family = 'netframework'
                $this.Version = [SemanticVersion]::new([int] $Matches.Major, [int] $Matches.Minor)
                break
            }
            '^(?<Family>[A-Za-z.]+)(?<Version>\d+(?:\.\d+){0,2})$'
            {
                # net5.0
                # .netframework4.5
                # MonoTouch10.0, Windows8.0, etc.
                $this.Family = $Matches.Family.ToLowerInvariant()
                $this.Version = [SemanticVersion]::Parse($Matches.Version)
                break
            }

            '^(?<Family>[A-Za-z.]+)$'
            {
                # portable
                $this.Family = $Matches.Family.ToLowerInvariant()
                break
            }

            default
            {
                throw [ArgumentOutOfRangeException]::new('framework', $framework, "Framework family '$($parts[0])' is not supported.")
            }
        }

        $sb = [StringBuilder]::new()
        switch ($this.Family)
        {
            'netframework'
            {
                $sb.Append('net').Append($this.Version.Major).Append($this.Version.Minor)
                if ($this.Version.Build -gt 0)
                {
                    $sb.Append($this.Version.Build)
                }
            }
            default
            {
                $sb.Append($this.Family).Append($this.Version)
            }
        }

        if ($parts.Length -gt 1)
        {
            # cheating
            $sb.Append('-').Append($parts[1])
        }

        $this.Value = $sb.ToString()
    }

    [string] ToString()
    {
        return $this.Value
    }

    static [Framework] Parse([string] $framework)
    {
        return $framework ? [Framework]::new($framework) : $null
    }

    hidden static [string[]] $FamilyOrder = @(
        'netstandard',
        'portable',
        'netframework',
        'netcore', # premature .NET Core values
        'netcoreapp',
        'net' # net5.0 and later.
    )

    hidden static [int] GetFamilyIndex([string] $family)
    {
        $result = [Framework]::FamilyOrder.IndexOf($family)
        if ($result -lt 0)
        {
            return [int]::MaxValue
        }
        return $result
    }

    [bool] Equals([object] $that)
    {
        return $that -is [Framework] -and $this.Value -eq $that.Value
    }

    [bool] IsEquivalentTo([Framework] $that)
    {
        return $that -and $this.Family -eq $that.Family -and $this.Version -eq $that.Version
    }

    [bool] IsGreaterOrEqualTo([Framework] $that)
    {
        return $that -and $this.Family -eq $that.Family -and $this.Version -ge $that.Version
    }

    [int] GetHashCode()
    {
        return $this.Value.GetHashCode()
    }

    [int] CompareTo($that)
    {
        if ($null -eq $that)
        {
            return 1;
        }

        [int] $diff = 0

        if ($this.Family -ne $that.Family)
        {
            # Compare families.  Everything not found is considered
            $thisIndex = [Framework]::GetFamilyIndex($this.Family)
            $thatIndex = [Framework]::GetFamilyIndex($that.Family)
            $diff = $thisIndex.CompareTo($thatIndex)
            if ($diff -ne 0) { return $diff; }
        }

        $diff = $this.Version.CompareTo($that.Version)
        if ($diff -ne 0) { return $diff; }

        # LATER: flesh out if needed.
        $thisOptionsLength = if ($this.Options) { $this.Options.Length } else { 0 }
        $thatOptionsLength = if ($that.Options) { $that.Options.Length } else { 0 }
        return $thisOptionsLength.CompareTo($thatOptionsLength)
    }
}

class ContentFileItem
{
    [string] $Include
    [string] $Exclude
    [string] $BuildAction = 'Compile'
    [bool] $CopyToOutput = $false
    [bool] $Flatten = $false
}

class FrameworkAssembly
{
    [string] $AssemblyName
    [Framework[]] $TargetFramework
}

class PackageType
{
    [string] $Name
    [SemanticVersion] $Version
}

class Reference
{
    [string] $File

    [string] ToString()
    {
        return $this.File
    }
}

class ReferenceGroup
{
    [Framework] $TargetFramework
    [List[Reference]] $References = [List[Reference]]::new()
}

class Dependency
{
    [Alias("Name")]
    [string] $Id
    [SemanticVersionRange] $Version

    [string] $Include
    [string] $Exclude

    [string] ToString()
    {
        return "{0}:{1}" -f $this.Id, $this.Version
    }
}

class NuspecFrameworkReferenceGroup
{
    [Framework] $TargetFramework

    [List[PSCustomObject]] $FrameworkReferences = [List[PSCustomObject]]::new()

    [string] ToString()
    {
        return $this.TargetFramework ? $this.TargetFramework.ToString() : 'default'
    }
}

class DependencyGroup
{
    # The owning package.
    [NuGetPackage] $Package

    # The target framework.
    [Framework] $TargetFramework

    # The invididual dependnecies.
    [List[Dependency]] $Dependencies = [List[Dependency]]::new()

    DependencyGroup([NuGetPackage] $package)
    {
        $this.Package = $package
    }

    [string] ToString()
    {
        return $this.TargetFramework ? $this.TargetFramework.ToString() : 'default'
    }
}

class NuGetPackage
{
    # REQUIRED - Unique identifier for the package
    [Alias("Name")]
    [string] $Id

    # REQUIRED - Version number of the package
    [SemanticVersion] $Version

    # Human-friendly name of the package displayed in NuGet clients
    [string] $Title

    # REQUIRED - Comma-separated list of authors of the package code
    [string] $Authors

    # Comma-separated list of the owners of the package - ignored by NuGet.org
    [Obsolete("Use Authors instead")]
    [string] $Owners

    # A long description of the package to show in NuGet clients
    [string] $Description

    # A description of the changes made in each release of the package
    # @since NuGet 1.5
    [string] $ReleaseNotes

    # A short description of the package to show in NuGet clients
    [Obsolete("Use Description instead")]
    [string] $Summary

    # The locale ID for the package.  Default is `en-US`.
    [string] $Language = 'en-US'

    # A URL to learn more about the package - the package project's home page
    [Uri] $ProjectUrl

    # A URL for an image to use in NuGet clients. Should be a 64x64 PNG with a transparent background
    [Obsolete("Use Icon instead")]
    [Uri] $IconUrl

    # Path to an image file within the package, often shown in UIs like nuget.org as the package icon.
    # Image file size is limited to 1 MB. Supported file formats include JPEG and PNG. We recommend an image resolution of 128x128.
    # @since NuGet 5.3.0
    [string] $Icon

    # When packing a readme file, you need to use the `readme` element to specify the package path, relative to the root of the package.
    # In addition to this, you need to make sure that the file is included in the package. Supported file formats include only Markdown (_.md_).
    #
    # For example, you would add the following to your nuspec in order to pack a readme file with your project:
    # @since NuGet 5.10.0-preview.2
    [string] $Readme

    # A URL for a license to the package
    [Uri] $LicenseUrl

    # Copyright details for the package
    # @since NuGet 1.5
    [string] $Copyright

    # Boolean - does the client need to ensure the package license is accepted before it is installed?  Default: false
    [bool] $RequireLicenseAcceptance = $false

    # A Boolean value specifying whether the package is be marked as a development-only-dependency, which prevents the package from being included as a dependency in other packages.
    # With PackageReference (NuGet 4.8+), this flag also means that it will exclude compile-time assets from compilation.
    # @since NuGet 2.8
    [bool] $DevelopmentDependency = $false

    # A space delimited list of tags and keywords that describe the package for use by NuGet repositories providing search capabilties
    [string[]] $Tags

    # For internal NuGet use only.
    # @since NuGet 3.3
    [Nullable[bool]] $Serviceable

    # Repository metadata, consisting of four optional attributes: `type` and `url` (4.0+), and `branch` and `commit` (4.6+).
    # These attributes allow you to map the `.nupkg` to the repository that built it, with the potential to get as detailed as the individual branch name and / or commit SHA-1 hash that built the package.
    # This should be a publicly available url that can be invoked directly by a version control software. It should not be an html page as this is meant for the computer.
    # For linking to project page, use the `projectUrl` field, instead.
    [PSCustomObject] $Repository

    # The minimum NuGet client version needed to install this package.
    [SemanticVersion] $MinClientVersion

    # An SPDX license expression or path to a license file within the package, often shown in UIs like nuget.org.
    #
    # If you're licensing the package under a common license, like MIT or BSD-2-Clause, use the associated SPDX license identifier.
    #
    # For example: `<license type="expression">MIT</license>`
    [PSCustomObject] $License

    # A collection of packages to be installed as a group.
    # If the project target framework matches this value, then this group of packages will be installed.
    # An empty value serves as a fallback.
    [DependencyGroup[]] $Dependencies

    # Framework References are a .NET Core concept representing shared frameworks such as WPF or Windows Forms.
    # By specifying a shared framework, the package ensures that all its framework dependencies are included in the referencing project.
    # @since NuGet 5.1
    [NuspecFrameworkReferenceGroup[]] $FrameworkReferences

    # A collection of zero or more frameworkAssembly objects identifying .NET Framework assembly references that this package requires,
    # which ensures that references are added to projects consuming the package.
    # @since NuGet 1.2
    [FrameworkAssembly[]] $FrameworkAssemblies

    # A collection of zero or more `PackageType` objects specifying the type of the package if other than a traditional dependency package.
    # @since NuGet 3.5
    [PackageType[]] $PackageTypes

    # A collection of zero or more references naming assemblies in the package's `lib` folder that are added as project references.
    # References can also contain a group with a targetFramework attribute, that then contains references.
    # If omitted, all references in `lib` are included.
    # @since NuGet 1.5
    [ReferenceGroup[]] $References

    # A collection of zero or more references naming assemblies in the package's `lib` folder that are added as project references.
    # References can also contain a group with a targetFramework attribute, that then contains references.
    # If omitted, all references in `lib` are included.
    # @since NuGet 3.3
    [ContentFileItem[]] $ContentFiles

    # top-level files
    [PSCustomObject[]] $Files

    # @property TargetFrameworks
    hidden [Framework[]] _GetTargetFrameworks()
    {
        return $this.Dependencies.TargetFramework
    }

    hidden [Framework] ResolveTargetFramework([Framework] $framework)
    {
        if ($Global:VerbosePreference) { Write-Verbose "ResolveTargetFramework ${framework}" }
        if ($null -eq $Framework) { throw [ArgumentNullException]::new('framework') }

        [Framework[]] $frameworks = $this.TargetFrameworks

        if ($null -eq $frameworks -or $frameworks.Length -eq 0)
        {
            return $framework
        }

        $debug = !!$Global:DebugPreference

        # Try exact
        if ($debug) { Write-Debug "TEST $frameworks -contains $framework" }
        if ($frameworks -contains $framework)
        {
            if ($debug) { Write-Debug ("  => EXACT {0}" -f $framework) }
            return $framework
        }

        # Try equivalents (e.g. net40-client)
        [Framework[]] $best = $frameworks | Where-Object { $Framework.IsGreaterOrEqualTo($_) } | Sort-Object -Descending
        if ($debug) { Write-Debug "TEST $frameworks -contains one of: $best" }
        if ($best)
        {
            if ($debug) { Write-Debug ("  => WILDCARD {0} ({1} options: {2})" -f $best[0], $best.Length, ($best.Value | ConvertTo-Json -Compress)) }
            return $best[0]
        }

        # Try fallbacks
        $fallbacks = Get-FallbackFramework $Framework
        if ($debug) { Write-Debug "TEST $frameworks -contains one of: $fallbacks" }
        $best = $fallbacks | Where-Object { [Framework] $_ -in $frameworks }
        if ($best)
        {
            if ($debug) { Write-Debug ("  => FALLBACK {0} ({1} options)" -f $best[0], $best.Length) }
            return $best[0]
        }

        # XXX Not sure what to do here.
        # if ($defaultGroup = $this.Dependencies | Where-Object TargetFramework -eq $null)
        # {
        #     return $defaultGroup
        # }

        # No matching frameworks.
        # This actually exists in the wild in some cases (e.g., MSTest.TestAdapter 2.1.2).
        # The frameworks are listed in the build/ directory.

        if ($this -is [NuGetFilePackage])
        {
            $best = $this.Directory.GetDirectories('build') | ForEach-Object { $_.GetDirectories() } | Where-Object Name -in $fallbacks
            if ($best)
            {
                if ($debug) { Write-Debug ("  => build/ {0} ({1} options)" -f $best[0], $best.Length) }
                return $best[0]
            }
        }

        throw [NotSupportedException]::new('Package does not support framework.  For framework: {0}' -f $framework)
    }

    hidden [DependencyGroup] old_GetDependencyGroup([Framework] $framework)
    {
        if ($null -eq $Framework) { throw [ArgumentNullException]::new('framework') }

        if ($null -eq $this.Dependencies -or $this.Dependencies.Length -eq 0)
        {
            return $null # [DependencyGroup]::new($this)
        }

        [DependencyGroup[]] $best = $this.Dependencies | Where-Object TargetFramework -eq $framework
        if ($best)
        {
            if ($Global:VerbosePreference) { Write-Verbose ("  => EXACT {0}" -f $best.TargetFramework) }
            return $best
        }

        # Try equivalents (e.g. net40-client)
        [DependencyGroup[]] $best = $this.Dependencies | Where-Object { $Framework.IsEquivalentTo($_.TargetFramework) }
        if ($best)
        {
            if ($Global:VerbosePreference) { Write-Verbose ("  => WILDCARD {0}" -f $best.TargetFramework) }
            return $best
        }

        # Try fallbacks
        [Framework[]] $fallbacks = Get-FallbackFramework $Framework
        $best = $this.Dependencies | Where-Object { $_.TargetFramework -in $fallbacks }
        if ($best)
        {
            if ($Global:VerbosePreference) { Write-Verbose ("  => BEST {0}" -f $best[0].TargetFramework) }
            return $best[0]
        }

        if ($defaultGroup = $this.Dependencies | Where-Object TargetFramework -eq $null)
        {
            return $defaultGroup
        }

        # No matching frameworks.
        # This actually exists in the wild in some cases (e.g., MSTest.TestAdapter 2.1.2).
        # The frameworks are listed in the build/ directory.

        if ($this -is [NuGetFilePackage])
        {
            $packageDir = [FileInfo]::new($this.Path).Directory
            if ($packageDir.GetDirectories('build').GetDirectories() | Where-Object Name -in $fallbacks | Select-Object -First 1)
            {
                # Found one!
                return $null
            }
        }

        throw [NotSupportedException]::new('Package does not support framework.  For framework: {0}' -f $framework)
    }

    [DependencyGroup] GetDependencyGroup([Framework] $framework)
    {
        if ($null -eq $Framework) { throw [ArgumentNullException]::new('framework') }

        if ($null -eq $this.Dependencies -or $this.Dependencies.Length -eq 0)
        {
            return $null
        }

        # Resolve the target framework, then look at dependencies.
        [Framework] $resolvedFramework = $this.ResolveTargetFramework($framework)

        [DependencyGroup[]] $matches = $this.Dependencies | Where-Object TargetFramework -eq $resolvedFramework
        switch ($matches.Length)
        {
            0
            {
                # Fall through.
            }
            1
            {
                if ($Global:VerbosePreference) { Write-Verbose ("  => EXACT {0}" -f $matches[0].TargetFramework) }
                return $matches[0]
            }
            default
            {
                Write-Warning ("{1} matches found for {0}" -f $framework, $matches.Length)
                if ($Global:VerbosePreference) { Write-Verbose ("  => EXACT {0} ({1} options)" -f $matches[0].TargetFramework, $matches.Length) }
                return $matches[0]
            }
        }

        # Framework is unknown or not supported, see if there is a "default" section.
        if ($defaultGroup = $this.Dependencies | Where-Object TargetFramework -eq $null)
        {
            return $defaultGroup
        }

        throw [NotSupportedException]::new('Package does not support framework.  For framework: {0}' -f $framework)
    }

    [Dependency[]] GetDependencies([Framework] $framework)
    {
        $group = $this.GetDependencyGroup($Framework)
        if ($null -eq $group)
        {
            return @()
        }

        return $group.Dependencies
    }

    [Assembly[]] GetAssemblies([Framework] $framework)
    {
        throw [NotSupportedException]::new("For non-file package.")
    }
}

class NuGetFilePackage : NuGetPackage
{
    NuGetFilePackage([string] $path)
    {
        $this.Path = $path
    }

    # Path to nuspec.
    [Alias('PSPath')]
    [string] $Path

    # @property File
    hidden [FileInfo] _GetFile()
    {
        return [FileInfo]::new($this.Path)
    }

    # @property Directory
    hidden [DirectoryInfo] _GetDirectory()
    {
        return $this.File.Directory
    }

    hidden [FileInfo[]] GetAssemblyFiles([Framework] $framework)
    {
        if ($Global:VerbosePreference) { Write-Verbose "GetAssemblies $framework" }
        $debug = !!$Global:DebugPreference

        # Lib path
        $resolvedFramework = $this.ResolveTargetFramework($framework)
        if ($null -eq $resolvedFramework)
        {
            if ($debug) { Write-Debug "GetAssemblies $framework => no matching framework" }
            return @()
        }

        $libFramework = [DirectoryInfo]::new([Path]::Combine($this._GetDirectory(), 'lib', $resolvedFramework)) # e.g., lib/net45
        if (!$libFramework.Exists)
        {
            if ($debug) { Write-Debug "GetAssemblies $framework => ${libFramework} not found" }
            return @()
        }

        $result = $libFramework.GetFiles('*.dll')
        if ($debug) { Write-Debug "GetAssemblies $framework => ${libFramework} => [$($result.Name | ConvertTo-Json -Compress)]" }
        return $result
    }

    [Assembly[]] GetAssemblies([Framework] $framework)
    {
        $result = $this.GetAssemblyFiles($framework)
        return $result | ForEach-Object { [Assembly]::LoadFile($_.FullName) }
    }

    [AssemblyName[]] GetAssemblyNames([Framework] $framework)
    {
        $result = $this.GetAssemblyFiles($framework)
        return $result | ForEach-Object { [AssemblyName]::GetAssemblyName($_.FullName) }
    }
}

class NuGetRemotePackage : NuGetPackage
{
    # The name of the NuGet package source.
    [string] $Source

    # The number of downloads.
    [Nullable[int]] $Downloads
}

function Get-KnownFramework
{
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([Framework])]
    param
    (
        [Parameter(ParameterSetName = 'List')]
        [switch] $List
    )

    switch ($PSCmdlet.ParameterSetName)
    {
        'List'
        {
            $FallbackMap.Keys | Sort-Object
        }
    }
}

function Get-FallbackFramework
{
    [CmdletBinding(DefaultParameterSetName = 'List')]
    [OutputType([Framework])]
    param
    (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [Framework] $Framework
    )

    process
    {
        Write-Verbose "Getting fallback frameworks for $Framework"
        [ref] $result = $null
        if ($FallbackMap.TryGetValue($Framework, $result))
        {
            return $result.Value
        }

        $fuzzy = $FallbackMap.Keys | Where-Object { $Framework.IsGreaterOrEqualTo($_) } | Sort-Object -Descending
        if ($fuzzy)
        {
            if ($Global:DebugPreference) { Write-Debug "$Framework => $($Fuzzy[0])" }
            return Get-FallbackFramework $fuzzy[0]
        }
    }
}

function GetXmlPath([XmlNode] $node)
{
    if ($node.NodeType -eq 'Attribute')
    {
        return '{0}/@{1}' -f (GetXmlPath $node.OwnerElement), $node.Name
    }

    [Stack[string]] $stack = [Stack[string]]::new()
    for ($n = $node; $n -and $n.NodeType -notin 'Document'; $n = $n.ParentNode)
    {
        $stack.Push($n.Name)
    }

    return '/' + [string]::Join('/', $stack)
}

function Write-WarningAboutNode([XmlNode] $node)
{
    switch ($node.NodeType)
    {
        'Attribute'
        {
            switch -wildcard ($node.Name)
            {
                'xmlns' { return } # swallow
                'xmlns:*' { return } # swallow
            }
        }
    }

    Write-Warning ("Unexpected {0}: {1}: {2}" -f $node.NodeType.ToString().ToLowerInvariant(), (GetXmlPath $node), $node.OuterXml)
}

function Assert-HasNoChildNodes([XmlElement] $Element)
{
    switch ($Element.ChildNodes)
    {
        default { Write-WarningAboutNode $_ }
    }
}

<#
.SYNOPSIS
Has no attributes.
.NOTES
`xmlns` and `xmlns:` namespace are ignored.
#>
function Assert-HasNoAttributes([XmlElement] $Element)
{
    foreach ($attribute in $Element.Attributes)
    {
        Write-WarningAboutNode $attribute
    }
}

<#
.SYNOPSIS
If there are children, they are all non-text-nodes.
#>
function Assert-HasNoTextNode([XmlElement] $Element, [string[]] $LocalName)
{
    switch ($Element.ChildNodes)
    {
        { $_.NodeType -notin 'Comment', 'Element' }
        {
            Write-Warning ("Element {0} has child {1}: {2}" -f (GetXmlPath $Element), $_.Name, $_.OuterXml)
        }
    }
}

<#
.SYNOPSIS
Process `<dependency/>` tag.
#>
filter MapDependencyXmlToObject
{
    if ($null -eq $_) { return }

    Assert-HasNoChildNodes $_

    $result = [Dependency]::new()

    switch ($_.Attributes)
    {
        { $_.LocalName -cin 'id', 'version', 'include', 'exclude' }
        {
            $result.($_.LocalName) = $_.Value
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $result
}

<#
.SYNOPSIS
Process `<group/>` tag under `<dependencies/>`, or a flat-list `<dependencies/>` tag.

.NOTES
The group format cannot be intermixed with a flat list.

.LINK
https://learn.microsoft.com/en-us/nuget/reference/nuspec#dependency-groups
#>
filter MapDependencyGroupXmlToObject([NuGetPackage] $package)
{
    if ($null -eq $_) { return }
    Assert-HasNoTextNode $_

    $dependencyGroup = [DependencyGroup]::new($package)

    switch ($_.Attributes)
    {
        { $_.LocalName -ceq 'targetFramework' }
        {
            $dependencyGroup.TargetFramework = $_.Value
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    switch ($_.ChildNodes)
    {
        { $_.LocalName -ceq 'dependency' }
        {
            $dependencyGroup.Dependencies.Add(($_ | MapDependencyXmlToObject))
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $dependencyGroup
}


<#
.SYNOPSIS
Process `<dependencies/>` tag.

.NOTES
The group format cannot be intermixed with a flat list.

.LINK
https://learn.microsoft.com/en-us/nuget/reference/nuspec#dependencies-element
#>
filter MapDependenciesXmlToObject([NuGetPackage] $package)
{
    if ($null -eq $_) { return }
    Assert-HasNoTextNode $_

    if ($_.ChildNodes | Where-Object LocalName -ceq 'group' | Select-Object -First 1)
    {
        Assert-HasNoAttributes $_

        # 2.0 format: <group/> tags under <dependencies/>
        switch ($_.ChildNodes)
        {
            { $_.LocalName -ceq 'group' }
            {
                $_ | MapDependencyGroupXmlToObject $package
            }

            default
            {
                Write-WarningAboutNode $_
            }
        }
        return
    }
    else
    {
        # 1.0 format: this *IS* a group.  The only group.
        $_ | MapDependencyGroupXmlToObject $package
    }
}

filter MapXmlToNuGetPackageFrameworkReferences
{
    if ($null -eq $_) { return }

    Assert-HasNoTextNode $_

    [NuspecFrameworkReferenceGroup] $result = $null

    switch ($_.Attributes)
    {
        { $_.LocalName -ceq 'targetFramework' }
        {
            $result ??= [NuspecFrameworkReferenceGroup]::new()
            $result.TargetFramework = $_.Value
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    $hasGroups = $false

    switch ($_.ChildNodes)
    {
        { $_.LocalName -ceq 'frameworkReference' }
        {
            if ($hasGroups)
            {
                Write-WarningAboutNode $_
                break
            }

            $result ??= [NuspecFrameworkReferenceGroup]::new()
            $result.FrameworkReferences.Add(($_ | MapXmlToStringOrObject))
        }

        { $_.LocalName -ceq 'group' }
        {
            $hasGroups = $true
            if ($null -ne $result)
            {
                Write-WarningAboutNode $_
                break
            }

            $_ | MapXmlToNuGetPackageFrameworkReferences
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    if ($null -ne $result)
    {
        return $result
    }
}


filter MapXmlToNuGetPackageFrameworkReferences
{
    if ($null -eq $_) { return }

    Assert-HasNoTextNode $_

    [NuspecFrameworkReferenceGroup] $result = $null

    switch ($_.Attributes)
    {
        { $_.LocalName -ceq 'targetFramework' }
        {
            $result ??= [NuspecFrameworkReferenceGroup]::new()
            $result.TargetFramework = $_.Value
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    $hasGroups = $false

    switch ($_.ChildNodes)
    {
        { $_.LocalName -ceq 'frameworkReference' }
        {
            if ($hasGroups)
            {
                Write-WarningAboutNode $_
                break
            }

            $result ??= [NuspecFrameworkReferenceGroup]::new()
            $result.FrameworkReferences.Add(($_ | MapXmlToStringOrObject))
        }

        { $_.LocalName -ceq 'group' }
        {
            $hasGroups = $true
            if ($null -ne $result)
            {
                Write-WarningAboutNode $_
                break
            }

            $_ | MapXmlToNuGetPackageFrameworkReferences
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    if ($null -ne $result)
    {
        return $result
    }
}

filter MapXmlToContentFile
{
    if ($null -eq $_) { return }
    if ($_.LocalName -cne 'files')
    {
        Write-WarningAboutNode $_
        return
    }

    Assert-HasNoChildNodes $_

    $result = [ContentFileItem]::new()

    switch ($_.Attributes)
    {
        { $_.LocalName -cin 'include', 'exclude', 'buildAction', 'copyToOutput', 'flatten' }
        {
            $result.($_.LocalName) = $_.Value
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $result
}

filter MapXmlToContentFiles
{
    if ($null -eq $_) { return }

    Assert-HasNoAttributes $_
    Assert-HasNoTextNode $_

    $_.ChildNodes | MapXmlToContentFile
}

filter MapXmlToFrameworkAssembly
{
    if ($null -eq $_) { return }
    if ($_.LocalName -cne 'frameworkAssembly')
    {
        Write-WarningAboutNode $_
        return
    }

    Assert-HasNoChildNodes $_

    $result = [FrameworkAssembly]::new()

    switch ($_.Attributes)
    {
        { $_.LocalName -ceq 'assemblyName' }
        {
            $result.($_.LocalName) = $_.Value
        }

        { $_.LocalName -ceq 'targetFramework' }
        {
            $result.($_.LocalName) = $_.Value -split '\s*,\s*'
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $result
}
filter MapXmlToFrameworkAssemblies
{
    if ($null -eq $_) { return }

    Assert-HasNoAttributes $_
    Assert-HasNoTextNode $_

    $_.ChildNodes | MapXmlToFrameworkAssembly
}

filter MapXmlToPackageType
{
    if ($null -eq $_) { return }
    if ($_.LocalName -cne 'packageType')
    {
        Write-WarningAboutNode $_
        return
    }

    Assert-HasNoChildNodes $_

    $result = [PackageType]::new()

    switch ($_.Attributes)
    {
        { $_.LocalName -cin 'name', 'version' }
        {
            $result.($_.LocalName) = $_.Value
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $result
}

filter MapXmlToPackageTypes
{
    if ($null -eq $_) { return }

    Assert-HasNoAttributes $_
    Assert-HasNoTextNode $_

    $_.ChildNodes | MapXmlToPackageType
}

filter MapXmlToReference
{
    if ($null -eq $_) { return }
    if ($_.LocalName -cne 'reference')
    {
        Write-WarningAboutNode $_
        return
    }

    Assert-HasNoChildNodes $_

    $result = [Reference]::new()

    switch ($_.Attributes)
    {
        { $_.LocalName -cin 'file' }
        {
            $result.($_.LocalName) = $_.Value
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $result
}


filter MapXmlToReferences
{
    if ($null -eq $_) { return }

    Assert-HasNoTextNode $_

    [ReferenceGroup] $result = $null

    switch ($_.Attributes)
    {
        { $_.LocalName -ceq 'targetFramework' }
        {
            $result ??= [ReferenceGroup]::new()
            $result.TargetFramework = $_.Value
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    $hasGroups = $false

    switch ($_.ChildNodes)
    {
        { $_.LocalName -ceq 'reference' }
        {
            if ($hasGroups)
            {
                Write-WarningAboutNode $_
                break
            }

            $result ??= [ReferenceGroup]::new()
            $result.References.Add(($_ | MapXmlToReference))
        }

        { $_.LocalName -ceq 'group' }
        {
            $hasGroups = $true
            if ($null -ne $result)
            {
                Write-WarningAboutNode $_
                break
            }

            $_ | MapXmlToReferences
        }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    if ($null -ne $result)
    {
        return $result
    }
}


filter MapXmlToText
{
    Assert-HasNoAttributes $_

    switch ($_.ChildNodes)
    {
        { $_.NodeType -notin 'Text', 'Comment', 'CDATA' }
        {
            Write-Warning ("Element {0} has child {1}: {2}" -f (GetXmlPath $_), $_.Name, $_.OuterXml)
        }
    }

    return $_.InnerText
}

filter MapXmlToStringOrObject
{
    $hash = @{}

    foreach ($attr in $_.Attributes)
    {
        $hash.Add($attr.LocalName, $attr.Value)
    }

    switch ($_.ChildNodes)
    {
        { $_.NodeType -eq 'Element' }
        {
            $hash.Add($_.LocalName, ($_ | MapXmlToStringOrObject))
        }

        { $_.NodeType -in 'Text', 'CDATA' }
        {
            $hash.Add('value', $_.Value)
        }

        { $_.NodeType -in 'Comment' } { }

        default
        {
            Write-WarningAboutNode $_
        }
    }

    return [PSCustomObject] $hash
}

filter MapXmlToNuGetPackage([NuGetPackage] $package)
{
    if ($null -eq $_) { return }

    Assert-HasNoAttributes $_
    Assert-HasNoTextNode $_

    switch ($_.ChildNodes)
    {
        { $_.LocalName -cin 'files' }
        {
            $package.($_.LocalName) = $_ | MapXmlToFiles
        }

        { $_.LocalName -eq 'metadata' }
        {
            if ($null -eq $_) { break }

            Assert-HasNoTextNode $_

            switch ($_.Attributes)
            {
                { $_.LocalName -in 'minClientVersion' }
                {
                    $package.($_.LocalName) = $_.Value
                }

                default
                {
                    Write-WarningAboutNode $_
                }
            }

            switch ($_.ChildNodes)
            {
                { $_.LocalName -cin 'id', 'version', 'title', 'authors', 'owners', 'description', 'releaseNotes', 'summary', 'language', 'projectUrl', 'iconUrl', 'icon', 'readme', 'licenseUrl', 'copyright', 'requireLicenseAcceptance', 'developmentDependency', 'serviceable' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToText
                }

                { $_.LocalName -cin 'tags' }
                {
                    $package.($_.LocalName) = ($_ | MapXmlToText) -split ' +'
                }

                { $_.LocalName -cin 'license', 'repository' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToStringOrObject
                }

                { $_.LocalName -ceq 'dependencies' }
                {
                    $package.($_.LocalName) = $_ | MapDependenciesXmlToObject $package
                }

                { $_.LocalName -ceq 'frameworkReferences' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToNuGetPackageFrameworkReferences
                }

                { $_.LocalName -ceq 'frameworkAssemblies' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToFrameworkAssemblies
                }

                { $_.LocalName -ceq 'contentFiles' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToContentFiles
                }

                { $_.LocalName -ceq 'packageTypes' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToPackageTypes
                }

                { $_.LocalName -ceq 'references' }
                {
                    $package.($_.LocalName) = $_ | MapXmlToReferences
                }

                default
                {
                    Write-WarningAboutNode $_
                }
            }
        }
        default
        {
            Write-WarningAboutNode $_
        }
    }

    return $package
}

filter MapFileInfoToNuGetPackage
{
    $xml = [xml]($_ | Get-Content)
    if ($xml)
    {
        $package = [NuGetFilePackage]::new($_)
        $xml.DocumentElement | MapXmlToNuGetPackage $package
    }
}

filter AddVersionToFile([switch] $Prerelease)
{
    $Version = [SemanticVersion]::Parse($_.Name)

    if (!$Prerelease -and $Version.PrereleaseLabel)
    {
        # Filter out prereleases.
        return
    }

    Add-Member -PassThru -InputObject $_ -NotePropertyName 'Version' -NotePropertyValue $Version
}

[string[]] $NotPackages = @('.tools')

class IdArgumentCompleter : IArgumentCompleter
{
    static hidden [CompletionResult[]] $Empty = [Array]::Empty[CompletionResult]()

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
    ) {
        [DirectoryInfo] $GlobalPackages = Get-NuGetCacheLocation 'global-packages'
        if ($GlobalPackages.Exists)
        {
            return [CompletionResult[]] (
                $GlobalPackages.EnumerateDirectories("${WordToComplete}*") |
                    Where-Object { $_.Name -notlike $NotPackages } |
                    ForEach-Object { [CompletionResult]::new($_.Name)}
            )
        }

        return [IdArgumentCompleter]::Empty
    }
}

class VersionArgumentCompleter : IArgumentCompleter
{
    static hidden [CompletionResult[]] $Empty = [Array]::Empty[CompletionResult]()

    [IEnumerable[CompletionResult]] CompleteArgument(
        [string] $CommandName,
        [string] $ParameterName,
        [string] $WordToComplete,
        [System.Management.Automation.Language.CommandAst] $CommandAst,
        [System.Collections.IDictionary] $FakeBoundParameters
    ) {
        if ($FakeBoundParameters.Id)
        {
            [DirectoryInfo] $GlobalPackages = Get-NuGetCacheLocation 'global-packages'
            if ($GlobalPackages.Exists)
            {
                return [CompletionResult[]] (
                    $GlobalPackages.EnumerateDirectories($FakeBoundParameters.Id.ToLowerInvariant()).EnumerateDirectories("${WordToComplete}*") |
                        ForEach-Object {
                            [CompletionResult]::new($_.Name, $_.Name, [CompletionResultType]::Text, "$($_.Parent.Name) $($_.Name)")
                        }
                )
            }
        }

        return [VersionArgumentCompleter]::Empty
    }
}

<#
.SYNOPSIS
Loads the given NuGet package cached locally.
#>
function Get-NuGetPackage
{
    [CmdletBinding()]
    [OutputType([NuGetFilePackage])]
    param
    (
        # The package ID.
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [ArgumentCompleter([IdArgumentCompleter])]
        [Alias("Name")]
        [string] $Id,

        # The specific package version, if available.
        # By default, only the latest is returned.
        #
        # Cannot be specified with -All.
        [Parameter(Position = 1, ValueFromPipelineByPropertyName)]
        [SemanticVersionTransformationAttribute()]
        [ArgumentCompleter([VersionArgumentCompleter])]
        [SemanticVersion] $Version,

        # Indicates that this cmdlet get all versions, not just the latest.
        # By default, only the latest is returned.
        #
        # Cannot be specified with -Version.
        [Parameter()]
        [switch] $All,

        # Include prerelease.
        [Parameter()]
        [switch] $Prerelease
    )

    begin
    {
        $GlobalPackagesPath = Get-NuGetCacheLocation 'global-packages'
    }

    process
    {
        $PackagePath = [Path]::Combine($GlobalPackagesPath, $Id.ToLowerInvariant())

        if ($All)
        {
            Get-ChildItem -LiteralPath:$PackagePath -Depth 1 -Include '*.nuspec' | MapFileInfoToNuGetPackage
        }
        elseif ($null -ne $Version)
        {
            Get-ChildItem -LiteralPath:$PackagePath -Directory | AddVersionToFile -Prerelease:$Prerelease | Where-Object Version -eq $Version | Get-ChildItem -Include '*.nuspec' | MapFileInfoToNuGetPackage
        }
        else
        {
            Get-ChildItem -LiteralPath:$PackagePath -Directory | AddVersionToFile -Prerelease:$Prerelease | Sort-Object -Property Version -Descending | Select-Object -First 1 | Get-ChildItem -Include '*.nuspec' | MapFileInfoToNuGetPackage
        }
    }
}

<#
.SYNOPSIS
Reads the given .nuspec file and parses it into a `NuGetPackage` reference.
#>
function Read-Nuspec
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    [OutputType([NuGetFilePackage])]
    param
    (
        # Specifies a path to one or more locations. Wildcards are permitted.
        [Parameter(Mandatory = $false,
            Position = 0,
            ParameterSetName = "Path",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]] $Path,

        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = "LiteralPath",
            ValueFromPipelineByPropertyName,
            HelpMessage = "Literal path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath
    )

    process
    {

        switch ($PSCmdlet.ParameterSetName)
        {
            'Path' { Get-Item -Path:$Path | MapFileInfoToNuGetPackage }
            'LiteralPath' { Get-Item -LiteralPath:$LiteralPath | MapFileInfoToNuGetPackage }

            default { Write-Error -Category NotImplemented "$_ not implemented" }
        }
    }
}

class TreeCache
{
    [Dictionary[string, NuGetPackage]] $data = [Dictionary[string, NuGetPackage]]::new()

    [NuGetPackage] GetOrAdd([string] $id, [SemanticVersion] $version)
    {
        [NuGetPackage] $result = $Null

        $key = "{0}:{1}" -f $id, $version
        if (!$this.data.TryGetValue($key, [ref] $result))
        {
            $result = Get-NuGetPackage -Id:$id -Version:$version
            $this.data.Add($key, $result)
        }

        return $result
    }

    [NuGetPackage] GetOrAdd([Dependency] $dependency)
    {
        return $this.GetOrAdd($dependency.Id, $dependency.Version.Minimum)
    }
}

class NuGetDependencyTreeNode : IFormattable
{
    [Alias("Name")]
    [string] $Id
    [SemanticVersion] $Version
    [int] $Depth = 0
    [List[NuGetDependencyTreeNode]] $Children

    hidden [NuGetDependencyTreeNode] $Parent
    hidden [bool] $DepthExceeded
    hidden [bool] $Missing

    hidden [object] $Source

    NuGetDependencyTreeNode([NuGetDependencyTreeNode] $parent, [NuGetPackage] $package)
    {
        if ($null -eq $package) { throw [ArgumentNullException]::new('package') }
        $this.Parent = $parent
        $this.Source = $package
        $this.Id = $package.Id
        $this.Version = $package.Version

        if ($this.Parent)
        {
            $this.Depth = 1 + $this.Parent.Depth
            $this.Parent.Add($this)
        }
    }

    NuGetDependencyTreeNode([NuGetDependencyTreeNode] $parent, [Dependency] $dependency)
    {
        if ($null -eq $parent) { throw [ArgumentNullException]::new('parent') }
        if ($null -eq $dependency) { throw [ArgumentNullException]::new('dependency') }

        $this.Parent = $parent
        $this.Source = $dependency
        $this.Id = $dependency.Id
        $this.Version = $dependency.Version.Minimum

        if ($this.Parent)
        {
            $this.Depth = 1 + $this.Parent.Depth
            $this.Parent.Add($this)
        }
    }

    [void] Add([NuGetDependencyTreeNode] $child)
    {
        $this.Children ??= [List[NuGetDependencyTreeNode]]::new()
        $this.Children.Add($child)
    }

    hidden [string] GetIdDisplayString()
    {
        $result = ('  ' * $this.Depth) + $this.Id
        if ($this.DepthExceeded) { $result += '…' }
        if ($this.Missing) { $result += '!' }
        return $result

    }

    hidden [void] AppendPathTo([StringBuilder] $builder)
    {
        if ($this.Parent)
        {
            $this.Parent.AppendPathTo($builder)
            $builder.Append(' -> ')
        }

        $builder.Append($this.Id).Append(':').Append($this.Version)
    }

    [string] ToPathString()
    {
        $sb = [StringBuilder]::new()
        $this.AppendPathTo($sb)
        return $sb
    }

    [string] ToString()
    {
        return "{0}:{1}" -f $this.Id, $this.Version
    }

    [string] ToString([string] $format) { return $this.ToString($format, $null) }

    [string] ToString([string] $format, [IFormatProvider] $provider)
    {
        switch ($format)
        {
            '' { return $this.ToString() }
            'path' { return $this.ToPathString() }
        }

        throw [FormatException]::new("Unknown format '${_}'")
    }
}

filter MapPackageToNuGetTree( [NuGetDependencyTreeNode] $parent = $null, [Framework] $Framework, [int] $MaxDepth = 4)
{
    if ($null -eq $_) { return }

    $node = [NuGetDependencyTreeNode]::new($parent, $_)

    if ($DebugPreference)
    {
        Write-Debug ("{0}{1} {2}" -f ('----' * $node.Depth), $node.Id, $node.Version)
    }

    if ($node.Depth -ge $MaxDepth)
    {
        $node.DepthExceeded = $true
        Write-Information "Exceeded depth ${MaxDepth}."
        Write-Output $node
        return
    }

    [NuGetPackage] $package = $null
    if ($_ -is [NuGetPackage])
    {
        $package = $_
    }
    else
    {
        $package = $PackageCache.GetOrAdd($_)
        if ($null -eq $package)
        {
            $node.Missing = $true
            Write-Output $node
            return
        }
    }

    $dependencies = $package.GetDependencies($Framework)
    Write-Output $node
    $dependencies | Sort-Object Id | MapPackageToNuGetTree -Parent:$node -Framework:$Framework -MaxDepth:$MaxDepth
}

function Show-NuGetTree
{
    [CmdletBinding()]
    [OutputType([NuGetDependencyTreeNode])]
    param
    (
        # The package ID.
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [string] $Id,

        # The specific package version, if available.
        [Parameter(Mandatory, Position = 1, ValueFromPipelineByPropertyName)]
        [SemanticVersionTransformationAttribute()]
        [SemanticVersion] $Version,

        # The framework for which to show.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Framework] $Framework = $DefaultFramework,

        # The maximum depth.
        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Depth = 2
    )

    process
    {
        $PackageCache = [TreeCache]::new()
        Get-NuGetPackage -Id:$Id -Version:$Version | MapPackageToNuGetTree -Framework:$Framework -MaxDepth:$Depth
    }

}

function Get-AssemblyName
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    param
    (
        # Specifies a path to one or more locations. Wildcards are permitted.
        [Parameter(ParameterSetName = "Path",
            Position = 0, Mandatory,

            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]] $Path,

        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(ParameterSetName = "LiteralPath",
            Position = 0, Mandatory,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Literal path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath
    )

    begin
    {
        filter ToAssemblyName
        {
            [AssemblyName]::GetAssemblyName($_.FullName) | Add-Member -MemberType NoteProperty -Name Path -Value $_.FullName -PassThru
        }
    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Path' { Get-Item -Path:$Path | ToAssemblyName }
            'LiteralPath' { Get-Item -LiteralPath:$LiteralPath | ToAssemblyName }
        }
    }
}

function Find-NuGetPackage
{
    [CmdletBinding(DefaultParameterSetName = "Id")]
    [OutputType([NuGetRemotePackage])]
    param
    (
        # The package ID.
        [Parameter(ParameterSetName = "Id", Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [string] $Id,

        # Include prerelease packages.
        [switch] $Prerelease,

        # One or more package sources to search.  The default is to search all available.
        [string[]] $Source

        # # The specific package version, if available.
        # [Parameter(ParameterSetName = "Id", Position = 1, ValueFromPipelineByPropertyName)]
        # [SemanticVersionTransformationAttribute()]
        # [SemanticVersion] $Version
    )

    process
    {
        $SearchArgs = @(
            '-NonInteractive',
            '-ForceEnglishOutput',
            '-Verbosity', 'Normal'
        )

        if ($Source)
        {
            $SearchArgs += $Source | ForEach-Object { '-Source'; $Source }
        }

        switch ($PSCmdlet.ParameterSetName)
        {
            'Id'
            {
                $SearchArgs += $Id
            }

            default { Write-Error -Category NotImplemented "$_ not implemented" }
        }

        if ($Prerelease)
        {
            $SearchArgs += '-PreRelease'
        }

        # MSCRAP: there is no dotnet nuget search.  That would be too easy.
        # So we currently parse the output of `nuget search`.
        $Source = $null
        $Current = $null
        $Downloads = 0

        switch -regex (nuget search $SearchArgs 2>&1)
        {
            # Error handler
            { $_ -is [ErrorRecord] }
            {
                Write-Error $_
            }

            # Debug handler: write to debug, then fall through to real case.
            { $DebugPreference } { Write-Debug "OUTPUT: ${_}" }

            # Parse the output
            '^====================$'
            {
                # Start of new source
                $Source = $null
                continue
            }

            '^Source: (?<Source>.+)'
            {
                $Source = $Matches.Source
                continue
            }

            '^> (?<Id>[^|]+) \| (?<Version>[^|]+) \| Downloads: (?<Downloads>[^|]+)$'
            {
                if ($Current)
                {
                    Write-Output $Current
                    $Current = $null
                }

                $Current = [NuGetRemotePackage] @{
                    Id = $Matches.Id
                    Version = [SemanticVersion] $Matches.Version
                    Downloads = [int]::TryParse($Matches.Downloads, [NumberStyles]::AllowThousands, [CultureInfo]::InvariantCulture, [ref] $Downloads) ? $Downloads : $null
                    Source = $Source
                }
                continue
            }

            '^--------------------$'
            {
                # Seprator, used after source, after short description
                if ($Current)
                {
                    Write-Output $Current
                    $Current = $null
                }

                continue
            }

            '^  (GET|POST|OK)\b'
            {
                # NuGet HTTP request debugging.
                # You can disable it with -Verbosity Quiet, but then you lose the title/downloads... >:(
                continue
            }

            '^  (\S.+)'
            {
                if ($Current)
                {
                    $Current.Description = $Current.Description ? $Current.Description + ' ' + $Matches[1] : $Matches[1]
                    continue
                }
            }

            '^$' { continue } # ignore blanks

            '^No results found\.$' { continue } # don't care really

            default
            {
                Write-Warning "Unknown line: '${_}'"
            }
        }
    }

}

#
# Main
#


Register-Framework 'netstandard1.0' -Recurse
Register-Framework 'netstandard1.1' 'netstandard1.0' -Recurse
Register-Framework 'netstandard1.2' 'netstandard1.1' -Recurse
Register-Framework 'netstandard1.3' 'netstandard1.2' -Recurse
Register-Framework 'netstandard1.4' 'netstandard1.3' -Recurse
Register-Framework 'netstandard1.5' 'netstandard1.4' -Recurse
Register-Framework 'netstandard1.6' 'netstandard1.5' -Recurse
Register-Framework 'netstandard2.0' 'netstandard1.6' -Recurse
Register-Framework 'netstandard2.1' 'netstandard2.0' -Recurse

Register-Framework '.NETFramework1.0' -Recurse
Register-Framework '.NETFramework1.1' '.NETFramework1.0' -Recurse
Register-Framework '.NETFramework2.0' '.NETFramework1.1' -Recurse
Register-Framework '.NETFramework3.0' '.NETFramework2.0' -Recurse
Register-Framework '.NETFramework3.5' '.NETFramework3.0' -Recurse
Register-Framework '.NETFramework4.0' '.NETFramework3.5' -Recurse

# hooray.
Register-Framework '.NETFramework4.5' '.NETFramework4.0', 'netstandard1.0' -Recurse

Register-Framework '.NETFramework4.5.1' '.NETFramework4.5' -Recurse
Register-Framework '.NETFramework4.5.2' '.NETFramework4.5.1' -Recurse
Register-Framework '.NETFramework4.6' '.NETFramework4.5.2' -Recurse
Register-Framework '.NETFramework4.6.1' '.NETFramework4.6' -Recurse
Register-Framework '.NETFramework4.6.2' '.NETFramework4.6.1' -Recurse
Register-Framework '.NETFramework4.7' '.NETFramework4.6.2' -Recurse
Register-Framework '.NETFramework4.7.1' '.NETFramework4.7' -Recurse

Register-Framework '.NETFramework4.7.2' '.NETFramework4.7.1', '.NETFramework4.6.2', '.NETFramework4.6.1', '.NETFramework4.6', '.NETFramework4.5.2', '.NETFramework4.5.1', '.NETFramework4.5', '.NETFramework4.0'
Register-Framework '.NETFramework4.7.2' 'netstandard2.0' -Recurse
Register-Framework '.NETFramework4.7.2' $FallbackMap['.NETFramework4.0']

Register-Framework '.NETFramework4.8' '.NETFramework4.7.2' -Recurse
Register-Framework '.NETFramework4.8.1' '.NETFramework4.8' -Recurse

Register-Framework 'netcoreapp1.0' 'netstandard1.0' -Recurse
Register-Framework 'netcoreapp1.1' 'netcoreapp1.0'
Register-Framework 'netcoreapp1.1' 'netstandard1.6' -Recurse

Register-Framework 'netcoreapp2.0' 'netcoreapp1.1'
Register-Framework 'netcoreapp2.0' 'netcoreapp1.0'
Register-Framework 'netcoreapp2.0' 'netstandard2.0' -Recurse

Register-Framework 'netcoreapp2.1' 'netcoreapp2.0', 'netstandard2.0' # do not recurse, have netstandard2.0 next
Register-Framework 'netcoreapp2.1' 'netcoreapp2.0', 'netstandard2.0' -Recurse
Register-Framework 'netcoreapp2.2' 'netcoreapp2.1' -Recurse
Register-Framework 'netcoreapp3.0' 'netcoreapp2.2' -Recurse
Register-Framework 'netcoreapp3.0' 'netstandard2.1' -Recurse
Register-Framework 'netcoreapp3.1' 'netcoreapp3.0' -Recurse

# Starting with .NET 5
Register-Framework 'net5.0' 'netcoreapp3.1' -Recurse

for ($major = 6; $major -le $DotnetVersion.Major + 2; $major++)
{
    Register-Framework ("net{0}.0" -f $major) ("net{0}.0" -f ($major - 1)) -Recurse
}

