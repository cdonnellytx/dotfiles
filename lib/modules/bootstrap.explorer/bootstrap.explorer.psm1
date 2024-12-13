#requires -version 7.0

<#

.SYNOPSIS
Shortcut window style.

.LINK
https://www.devguru.com/content/technologies/wsh/wshshortcut-windowstyle.html
#>
enum WindowStyle
{
    Default = 1
    Minimized = 7
    Maximized = 3
}

$Script:WshShell = New-Object -ComObject 'WScript.Shell'

function Get-Shortcut
{
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo])]
    param
    (
        # The path to the shortcut.
        [Parameter(Mandatory, Position = 0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias("PSPath")]
        [Alias("LiteralPath")]
        [string] $Path
    )

    process
    {
        Get-Item -LiteralPath:$Path | ForEach-Object { $WshShell.CreateShortcut($_) }
    }
}

function New-Shortcut
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        # The path to the shortcut.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("PSPath")]
        [Alias("LiteralPath")]
        [string] $Path,

        # The target of the shortcut.
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        # The arguments for the shortcut.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Arguments,

        # The shortcut window style.
        [Parameter()]
        [WindowStyle] $WindowStyle = [WindowStyle]::Default,

        [switch] $Force
    )

    if (!$Force -and (Test-Path -Path:$Path))
    {
        Write-Error -Category OperationStopped -CategoryTargetName $Path -Message "The path '${Path}' already exists."
        return
    }

    Confirm-PathIsShortcut @PSBoundParameters -PassThru
}

filter quoteparam
{
    switch -regex ($_)
    {
        '[ "]' { '"{0}"' -f ($_ -creplace '"', '""' )  }
        default { $_ }
    }
}

function Confirm-PathIsShortcut
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object])]
    param
    (
        # The path to the shortcut.
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [Alias("PSPath")]
        [Alias("LiteralPath")]
        [string] $Path,

        # The target of the shortcut.
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        # The arguments for the shortcut.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string[]] $Arguments,

        # The shortcut window style.
        [Parameter()]
        [WindowStyle] $WindowStyle = [WindowStyle]::Default,

        [switch] $Force,

        [switch] $PassThru
    )

    # CreateShortcut will load the .lnk if it exists, and ignore the error if it doesn't.
    $Shortcut = $WshShell.CreateShortcut($Path)
    $Shortcut.WindowStyle = [int] $WindowStyle
    $Shortcut.TargetPath = $Target
    $Shortcut.Arguments = ($Arguments | quoteparam) -join ' '

    if ($Force -or $PSCmdlet.ShouldProcess("Path: $($Shortcut.FullName), Target: $($Shortcut.TargetPath), Arguments: $($Shortcut.Arguments)", "Set Shortcut"))
    {
        $Shortcut.Save()
    }

    if ($PassThru)
    {
        return $Shortcut
    }
}
