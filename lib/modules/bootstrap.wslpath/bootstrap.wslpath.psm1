#requires -version 7.0

if (!$IsWindows)
{
    throw [NotSupportedException]::new("Only supported on Windows.")
}

<#
.SYNOPSIS
Converts paths between Windows and Linux syntax.

.INPUTS
System.String
    You can pipe a string that contains a path to this cmdlet.

.OUTPUTS
System.String
    The paths resolved in order of input.

.EXAMPLE
Get-WslPath -Unix C:\Windows, /usr/bin/bash

/mnt/c/Windows
/usr/bin/bash

.EXAMPLE
Get-WslPath -Mixed C:\Windows, /usr/bin/bash

C:/Windows
//wsl$/Contoso/usr/bin/bash

.EXAMPLE
Get-WslPath -Windows C:\Windows, /usr/bin/bash

C:\Windows
\\wsl$\Contoso\usr\bin\bash

#>
function Get-WslPath
{
    [CmdletBinding(DefaultParameterSetName = "Path")]
    [OutputType([string])]
    param
    (
        # Specifies a path to one or more locations.
        [Parameter(Mandatory,
            Position = 0,
            ParameterSetName = "Path",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage = "Path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [string[]] $Path,

        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(Mandatory,
            ParameterSetName = "LiteralPath",
            ValueFromPipelineByPropertyName,
            HelpMessage = "Literal path to one or more locations.")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        # Alternative way to select type.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [ValidateSet('unix', 'mixed', 'windows')]
        [string] $Type,

        # Translates the path to Unix format.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [switch] $Unix,

        # Translates the path to "mixed" format, which is a Windows format but with Unix slashes.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [switch] $Mixed,

        # Translates the path to Windows format.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [switch] $Windows,

        # Converts the result to absolute path format.
        [Parameter(ParameterSetName = 'Path')]
        [Parameter(ParameterSetName = 'LiteralPath')]
        [switch] $Absolute
    )

    begin
    {
        if ($Type)
        {
            if ($Unix -or $Mixed -or $Windows)
            {
                Write-Error -Category InvalidArgument -Message "Cannot specify 'Type' with type aliases (Unix: $Unix, mixed: $Mixed, windows: $Windows)"
                return
            }
        }
        elseif (!$Unix -and !$Mixed -and !$Windows)
        {
            $Type = 'unix'
        }
        else
        {
            $count = 0
            if ($Unix)    { $Type = 'unix'   ; $count++ }
            if ($Mixed)   { $Type = 'mixed'  ; $count++ }
            if ($Windows) { $Type = 'windows'; $count++ }
            if ($count -gt 1)
            {
                Write-Error -Category InvalidArgument -Message "Cannot specify multiple types (unix: $Unix, mixed: $Mixed, windows: $Windows)"
                return
            }
        }

    }

    process
    {
        [string[]] $paths = $null

        #
        # cdonnelly 2019-04-11: Can't use Resolve-PathParameters here because it does absolute pathing at the moment, and we optionally need relative
        #
        switch ($PSCmdlet.ParameterSetName)
        {
            'Path'
            {
                # Convert-Path resolves wildcards, etc. to absolute paths.
                $paths = $Path | ForEach-Object {

                    # Resolve any existing paths (including ones with wildcards).
                    # Treat all else as literals.
                    if ($_.IndexOfAny('*?') -ge 0)
                    {
                        # Wildcards.  Must try to expand.
                        try
                        {
                            $AbsolutePaths = $ExecutionContext.SessionState.Path.GetResolvedPSPathfromPSPath($_)
                        }
                        catch
                        {
                            # Eat error, path does not exist
                            Write-Verbose "Path not found: $_"
                        }
                    }

                    if (!$AbsolutePaths)
                    {
                        # Not found.  Treat input as literal path.
                        if ($Absolute -and ![IO.Path]::IsPathRooted($_))
                        {
                            # Must force to absolute path.
                            # PSCRAP: Join-Path blindly joins a rooted path to another.
                            return Join-Path -Path $PWD.Path -ChildPath $_
                        }

                        return $_
                    }
                    elseif ($Absolute)
                    {
                        return $AbsolutePaths
                    }
                    else
                    {
                        return $AbsolutePaths | ForEach-Object { $ExecutionContext.SessionState.Path.NormalizeRelativePath($_, $PWD.Path) }
                    }
                }
            }
            'LiteralPath'
            {
                # Relative: do nothing
                if ($Absolute)
                {
                    $paths = $LiteralPath | ForEach-Object {
                        # Not found.  Treat input as literal path.
                        if (![IO.Path]::IsPathRooted($_))
                        {
                            # Must force to absolute path.
                            # PSCRAP: Join-Path blindly joins a rooted path to another.
                            return Join-Path -Path $PWD.Path -ChildPath $_
                        }

                        return $_
                    }
                }
                else
                {
                    $paths = $LiteralPath
                }

            }
            default
            {
                throw [NotSupportedException]"For parameter set name: $($PSCmdlet.ParameterSetName)"
            }
        }

        switch ($Type)
        {
            'unix' {
                $paths -Replace '\\', '/' | ForEach-Object {
                    if ($_ -imatch '^(?<Drive>[A-Z]):(?<Rest>/.*)?')
                    {
                        '/mnt/' + $Matches['Drive'].ToLowerInvariant() + $Matches['Rest']
                    }
                    else
                    {
                        $_
                    }
                }
            }
            'mixed' {
                $paths -Replace '\\', '/' | ForEach-Object {
                    if ($_ -cmatch '^/mnt/(?<Drive>[a-z])(?<Rest>/.*)?')
                    {
                        $Matches['Drive'].ToUpperInvariant() + ':' + $Matches['Rest']
                    }
                    else
                    {
                        $_
                    }
                }
            }
            'windows' {
                $paths -Replace '/', '\' | ForEach-Object {
                    if ($_ -cmatch '^\\mnt\\(?<Drive>[a-z])(?<Rest>\\.*)?')
                    {
                        $Matches['Drive'].ToUpperInvariant() + ':' + $Matches['Rest']
                    }
                    else
                    {
                        $_
                    }
                }
            }
        }

    }
}

New-Alias -Name 'wslpath' -Value 'Get-WslPath'
