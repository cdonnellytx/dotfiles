using namespace System
using namespace System.IO

param
(
)

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Locates and launches JetBrains DotPeek with the specified parameters.
#>
function Invoke-FromInstallations
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # The version to run (wildcard).
        # Defaults to latest.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Version = '*',

        # The location of the DotPeek install.
        # By default it looks in the expected OS install location.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        # C:\Users\CRDONNELLY\AppData\Local\JetBrains\Installations\dotPeek222_000\dotPeek64.exe
        [string] $HomePath = ($IsWindows ? "${Env:LOCALAPPDATA}/JetBrains/Installations" : ""),

        # Gets all matching versions listed in precedence order.
        [switch] $List,

        # Arguments to pass to DotPeek.
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $ArgumentList
    )

    # DotPeek can have multiple versions installed.
    # We want the latest.
    $versions = Get-ChildItem -LiteralPath $HomePath -Include "dotPeek*" -Directory |
        Add-Member -PassThru -Type ScriptProperty -Name Version -Value { [Version] ($this.Name -creplace '^dotPeek', '' -creplace '_', '.') } |
        Where-Object -ErrorAction Ignore Version |
        Sort-Object -Descending Version

    if ($List)
    {
        return $versions
    }

    if (!$versions)
    {
        Write-Error -Category ObjectNotFound "No versions matching '${Version}' was found."
        return
    }

    [string[]] $exeInclude = if ($IsWindows)
    {
        if ([Environment]::Is64BitOperatingSystem) { 'dotPeek64.exe' } else { 'dotPeek32.exe' }
        'dotPeek.exe'
    }
    else
    {
        if ([Environment]::Is64BitOperatingSystem) { 'dotPeek64' } else { 'dotPeek32' }
        'dotPeek'
    }

    $exe = Get-ChildItem -Include $exeInclude -LiteralPath $versions[0].FullName | Select-Object -First 1
    if (!$exe)
    {
        Write-Error -Category ObjectNotFound "A version '${Version}' was found, but does not contain any executables."
        return
    }

    if ($PSCmdlet.ShouldProcess("${ArgumentList}", $exe.FullName))
    {
        & $exe $ArgumentList
    }
}

enum AppType
{
    Unknown
    Installation
    Toolbox
}

function FindAppNames()
{
    if ($IsWindows)
    {
        $JetBrainsRoot = [Path]::Combine($Env:LOCALAPPDATA, 'JetBrains')

        Get-ChildItem -Directory -LiteralPath "${JetBrainsRoot}\Toolbox\apps" -ErrorAction Ignore |
            Select-Object Name,
             @{ Name = 'Alias'; Expression = { $_.Name.ToLowerInvariant() -creplace '-u$', '' } }, # TODO probably others like -C
             @{ Name = 'Path'; Expression = 'FullName' },
             @{ Name = 'Type'; Expression = { [AppType]::Toolbox } }

        # Special location for ReSharper-bound dotCover/dotMemory/dotPeek/dotTrace
        # Format: <name><major>_<minor>
        Get-ChildItem -Directory -LiteralPath "${JetBrainsRoot}\Installations" -Include '*_*' -ErrorAction Ignore |
            Select-Object Name,
                @{ Name = 'Alias'; Expression = { $_.Name.ToLowerInvariant() -creplace '\d+.*', '' } }, # TODO probably others like -C
                @{ Name = 'Path'; Expression = 'FullName' },
                @{ Name = 'Type'; Expression = { [AppType]::Installation } }
    }
    else
    {
        Write-Error -Category NotImplemented "For $([System.Environment]::OSVersion)"
        return
    }
}


<#
.SYNOPSIS
Get the home path for the command.
.PRIVATE
#>
function ResolveHomePath([string] $Command, [string] $Version)
{
    if ($IsWindows)
    {
        $JetBrainsRoot = [Path]::Combine($Env:LOCALAPPDATA, 'JetBrains')

        Get-ChildItem -Directory -LiteralPath "${JetBrainsRoot}\Toolbox\apps" -Include $Command |
            Get-ChildItem -Directory -Include 'ch-0' |
            Get-ChildItem -Directory -Include $Version -Exclude '*.plugins' |
            Add-Member -PassThru -Type ScriptProperty -Name Version -Value { [Version] $this.Name } |
            Where-Object -ErrorAction Ignore Version

        switch -Wildcard ($Command)
        {
            'dot*'
            {
                # Special location for ReSharper-bound dotCover/dotMemory/dotPeek/dotTrace
                # Format: <name><major>_<minor>
                Get-ChildItem -LiteralPath "${JetBrainsRoot}\Installations" -Include "${Command}*" -Directory |
                    Add-Member -PassThru -Type ScriptProperty -Name Version -Value { [Version] ($this.Name.Substring($Command.Length) -creplace '_', '.') } |
                    Where-Object -ErrorAction Ignore Version
            }
        }
    }
    else
    {
        Write-Error -Category NotImplemented "For $([System.Environment]::OSVersion)"
        return
    }
}

function FindExeName([string] $Command)
{
    # xyzzy64.exe/xyzzy32.exe
    if ([Environment]::Is64BitOperatingSystem) { '{0}64' -f $Command } else { '{0}32' -f $Command }
    # xyzzy.exe
    $Command
}

filter FindExeDir
{
    # $_/bin ?? $_
    ($_ | Get-ChildItem -ErrorAction Ignore -Include 'bin') ?? $_
}

filter FindExeFullName([string] $Command)
{
    [string[]] $Include = FindExeName $Command
    if ($IsWindows)
    {
        $Include = $Include | ForEach-Object { '{0}.exe' -f $_ }
    }

    $_ | Get-ChildItem -Include $Include -Verbose
}

function Get-JetBrainsAppList
{

}

function Get-JetBrainsApp
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Command,

        # The version to run (wildcard).
        # Defaults to latest.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Version = '*',

        # Gets all matching versions listed in precedence order.
        [switch] $List
    )

    if ($VerbosePreference)
    {
        Write-Verbose "Get-JetBrainsApp -Command:$Command -Version:$Version"
    }

    $homePaths = ResolveHomePath $Command | Sort-Object -Descending Version
    if ($List)
    {
        return $homePaths
    }

    if (!$homePaths)
    {
        $Message = if ($Version -eq '*') { "No versions found." } else { "No versions matching '${Version}' was found." }
        Write-Error -Category ObjectNotFound -Message "${Command}: ${Message}"
        return
    }

    $HomePath = $HomePaths[0]

    $exe = $HomePath | FindExeDir | FindExeFullName -Command $Command
    if (!$exe)
    {
        Write-Error -Category ObjectNotFound "${Command}: A version '$($HomePath.Name)' was found, but does not contain any executables."
        return
    }

    return $exe | Select-Object -First 1
}

function Start-JetBrainsApp
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Command = $PSCmdlet.MyInvocation.InvocationName,

        # The version to run (wildcard).
        # Defaults to latest.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Version = '*',

        # Arguments to pass to DotPeek.
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]] $ArgumentList
    )

    if ($exe = Get-JetBrainsApp -Command:$Command -Version:$Version)
    {
        if ($PSCmdlet.ShouldProcess("${ArgumentList}", $exe.FullName))
        {
            & $exe $ArgumentList
        }
    }
}

#
# Main
#

FindAppNames | Select-Object @{ Name = 'Name'; Expression = 'Alias' } | New-Alias -Value 'Start-JetBrainsApp'
