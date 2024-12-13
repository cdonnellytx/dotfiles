#!/usr/bin/env -S pwsh -NoProfile

<#
.SYNOPSIS
Finds any local source control repositories in the given paths.

.DESCRIPTION
Finds any local Subversion or Git repositories.

.EXAMPLE
Find-Repositories.ps1
.EXAMPLE
Find-Repositories.ps1 -Command { git status }
#>

#Requires -Version 5.0
using namespace System.Collections.Generic;
using namespace System.IO;
using namespace System.Management.Automation;

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Default')]
param
(
    # Specifies a path to one or more locations. Wildcards are permitted. The default location is the current directory (.).
    [Parameter(
        Position = 0,
        Mandatory = $false,
        ParameterSetName = "Default",
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Path to one or more locations."
    )]
    [ValidateNotNullOrEmpty()]
    [SupportsWildcards()]
    [string[]] $Path,

    # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
    # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
    # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
    # characters as escape sequences.
    [Parameter(
        Mandatory = $true,
        ParameterSetName = "LiteralPath",
        ValueFromPipelineByPropertyName = $true,
        HelpMessage = "Literal path to one or more locations."
    )]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]] $LiteralPath,

    # Recurse at most this many levels.  Set to 0 to disable recursion.
    [Parameter()]
    [ValidateScript( { $_ -ge 0 })]
    [int] $Depth = 4,

    # Specify the repository type (git, svn).
    # Default is git; multiple can be specified.
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [ValidateSet("git", "svn", "hg")]
    [string[]] $Type = 'git',

    # Comamnd to execute on each found repository, if any.
    [Parameter()]
    [scriptblock] $Command
)

####################################################################################################################################

#
# Determine the paths
#
begin
{
    function Resolve-PathArgument
    {
        [CmdletBinding()]
        [OutputType([FileSystemInfo[]])]
        param
        (
            [string[]] $Path,
            [string[]] $LiteralPath
        )

        if ($Path)
        {
            return Get-Item -Force -Path $Path
        }
        elseif ($LiteralPath)
        {
            return Get-Item -Force -LiteralPath $LiteralPath
        }

        # No path args.
        # Assume current location in filesystem.
        return Get-Location -PSProvider Filesystem | Get-Item -Force
    }

    class Repository
    {
        hidden static [Hashtable] $typeToExtension = @{
            'svn' = '.svn'
            'git' = '.git'
            'hg' = '.hg'
        }

        hidden static [Hashtable] $extensionToType = @{
            '.svn' = 'svn'
            '.git' = 'git'
            '.hg' = 'hg'
        }

        static [string[]] $Extensions = [Repository]::extensionToType.Keys

        Repository([FileSystemInfo] $metaPath)
        {
            $this.MetaPath = $metaPath
            $this.Path = if ($metaPath -is [DirectoryInfo]) { $metaPath.Parent } else { $metaPath.Directory }
            $this.Type = [Repository]::extensionToType[$metaPath.Name]
        }

        [string] $Type
        [Alias("PSPath")]
        [FileSystemInfo] $Path
        hidden [FileSystemInfo] $MetaPath

        [string] ToString()
        {
            return $this.Path.FullName
        }
    }

    class RepositoryCommandResult
    {
        [string] $Type
        [Alias("PSPath")]
        [FileSystemInfo] $Path
        hidden [FileSystemInfo] $MetaPath
        [Nullable[int]] $ExitCode
        [object] $Output

        # https://stackoverflow.com/a/40365941

        RepositoryCommandResult([Repository] $repository, [object] $Output, [Nullable[int]] $ExitCode = $null)
        {
            $this.Path = $repository.Path
            $this.Type = $repository.Type
            $this.MetaPath = $repository.MetaPath
            $this.Output = $output
            $this.ExitCode = $ExitCode
        }

        [string] ToString()
        {
            return $this.Path.FullName
        }
    }

    <# MSCRAP: Get-ChildItem varies WILDLY between PowerShell Desktop 5.x and Core. #>
    function Get-RepositoryItem
    {
        [OutputType([FileSystemInfo])]
        param
        (
            [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
            [ValidateNotNull()]
            [FileSystemInfo] $Item,

            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string[]] $Include,

            [int] $Depth = 0
        )

        process
        {
            Write-Verbose "ENTRY Get-RepositoryItem -Item:$Item -Include:$Include -Depth:$Depth"
            $ChildDepth = $Depth - 1

            if (!$Item.Exists)
            {
                Write-Verbose "EXIT  Get-RepositoryItem: not found"
                return
            }

            # Stop crawling further if any repo extension is found, regardless of whether we're crawling it.
            # E.g. if this item is a Git repo, don't search it for Subversion repos.
            foreach ($extension in [Repository]::Extensions)
            {
                foreach ($child in $Item.EnumerateFileSystemInfos($extension))
                {
                    # It's one of the repository types.
                    if ($child.Name -like $Include)
                    {
                        # We want this repo type.
                        Write-Verbose "EXIT  Get-RepositoryItem: found $($child.Name) $($child.GetType())"
                        return $child
                    }

                    # We do not want this repo type, but need to flag that we found a repo type to stop crawling.
                    # We can do this by just nulling out ChildDepth.
                    if ($null -ne $ChildDepth)
                    {
                        Write-Verbose "$($Item.FullName): is a repo ($($child.Name)), will not crawl further."
                        $ChildDepth = $null
                    }
                }
            }

            if ($ChildDepth -ge 0)
            {
                # Crawl for more repos.
                $Item.EnumerateDirectories() | Get-RepositoryItem -Include:$Include -Depth:$ChildDepth
            }
        }
    }

    <#
    .SYNOPSIS
    Find repository metadata paths for each resolved path item.
    #>
    function Resolve-Repository
    {
        [CmdletBinding()]
        [OutputType([Repository[]])]
        param
        (
            # The items to search.
            [Parameter(Position = 0, Mandatory)]
            [ValidateNotNullOrEmpty()]
            [FileSystemInfo[]] $Items,

            # The repository metadata paths to include.
            [Parameter()]
            [string[]] $Include,

            # Recurse at most this many levels.  Set to 0 to disable recursion.
            [int] $Depth
        )

        $PathCache = [Dictionary[string, FileSystemInfo[]]]::new()

        foreach ($item in $items)
        {
            Write-Verbose "item: ${item}"

            if (!($item.Attributes -band [FileAttributes]::Directory))
            {
                Write-Warning "${item}: is a file"
                continue
            }

            # First, try finding descendant repos.
            $item | Get-RepositoryItem -Depth $Depth -Include $Include |
                ForEach-Object { [Repository]::new($_) } |
                Where-Object {
                    # Exclude nested repos; these are usually managed by the source control tool.
                    Write-Verbose "  found possible repository ${_}"
                    for ($parent = $_.Path.Parent; $parent -and $parent.FullName -ne $item.FullName; $parent = $parent.Parent)
                    {
                        if (!$PathCache.ContainsKey($parent.FullName))
                        {
                            Write-Verbose "      miss: $parent | Get-RepositoryItem -Include:$Include"
                            $PathCache.Add($parent.FullName, ($parent | Get-RepositoryItem -Include $Include))
                        }

                        if ($PathCache[$parent.FullName])
                        {
                            Write-Verbose "      REJECT: ${parent} => $($PathCache[$parent])"
                            return $false
                        }
                    }

                    return $true
                }
        }
    }

    #
    # Main
    #

    Set-StrictMode -Version Latest

    [string[]] $include = [Repository]::typeToExtension[$Type]
}

process
{
    [FileSystemInfo[]] $resolvedItems = Resolve-PathArgument -Path $Path -LiteralPath $LiteralPath

    if (!$Command)
    {
        # Find and return.
        Resolve-Repository -Items $resolvedItems -Include $Include -Depth $Depth
        return
    }

    # Find and process.
    Resolve-Repository -Items $resolvedItems -Include $Include -Depth $Depth | ForEach-Object {
        $repository = $_
        Push-Location -LiteralPath $repository.Path

        try
        {
            # PSCRAP: uuuuuuugh.  Want a better way to capture stderr.
            $output = & { & $Command 2>&1 }
            [RepositoryCommandResult]::new($repository, $output, $LastExitCode)
        }
        catch
        {
            [RepositoryCommandResult]::new($repository, $_, $_.Exception.HResult)
        }
        finally
        {
            Pop-Location
        }
    }
}