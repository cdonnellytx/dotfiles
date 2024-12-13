#!/usr/bin/env -S pwsh -NoProfile
#Requires -Version 7

<#
.SYNOPSIS
Finds all applications using Electron.

.DESCRIPTION
Finds all applications using Electron for the given paths.

If no paths are specified, the default application paths for the OS are searched.

.INPUTS
You can run this three ways:
- No arguments: Searches default OS paths.
- System.String[]: Path or LiteralPath (see Get-ChildItem for details)
- You can pipe a file system path.

.OUTPUTS
Custom objects containing the path to the executable, as well as the Electron version.

.NOTES
Electron apps are detected by looking for one or more of the following files:
- app.asar
- chrome_100_percent.pak
- chrome_200_percent.pak

Currently only supports Windows.
PowerShell 5.1 is not supported because its Get-ChildItem does not handle -Include correctly.

.EXAMPLE

.LINK
https://stackoverflow.com/questions/42342048/how-do-i-determine-if-an-application-is-built-by-electron-or-not
#>

using namespace System.IO;

[CmdletBinding(DefaultParameterSetName = 'LiteralPath')]
[OutputType([PSCustomObject])]
param
(
    # Specifies a path to one or more locations. Wildcards are permitted.
    [Parameter(Mandatory,
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
    [Parameter(Position = 0,
        ParameterSetName = "LiteralPath",
        ValueFromPipelineByPropertyName,
        HelpMessage = "Literal path to one or more locations.")]
    [Alias("PSPath")]
    [ValidateNotNullOrEmpty()]
    [string[]] $LiteralPath = (
        $IsWindows ? ($Env:LOCALAPPDATA, $Env:APPDATA, $Env:ProgramFiles, ${Env:ProgramFiles(x86)})
            : @()
    )
)

begin
{
    $SearchPatterns = 'app.asar', 'chrome_[12]00_percent.pak'

    <#
    .SYNOPSIS
    Find the Electron app directory for a given path.
    .INPUTS
    System.IO.FileSystemInfo
    #>
    filter GetAppDirectory
    {
        $dir = if ($_ -is [FileInfo]) { $_.Directory } else { $_.Parent }
        switch ($dir.Name)
        {
            # Go one higher.
            'resources'
            { 
                return $dir | GetAppDirectory
            }

            # Default: Stop going up.
            default
            {
                # 
                return $dir
            }
        }
    }
}

process
{
    $PathSplat = switch ($PSCmdlet.ParameterSetName)
    {
        'Path' { @{ Path = $Path } }
        'LiteralPath' { @{ LiteralPath = $LiteralPath } }
    }

    Write-Verbose "Find Electron apps in paths:`n$($PathSplat.Values | ConvertTo-Json)"

    Get-ChildItem @PathSplat -Recurse -File -Include $SearchPatterns |
        GetAppDirectory | Get-Unique |
        Get-ChildItem -Filter '*.exe' |
        Select-String -CaseSensitive 'Electron/(\d+\.\d+\.\d+[^%]*)' -List |
        Select-Object @{ Name = 'Version'; Expression = { $_.Matches[0].Groups[1].Value } }, Path

}    
