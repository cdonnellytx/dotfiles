Set-StrictMode -Version Latest

<#
.SYNOPSIS
Gets actual file system drives (not temp, not )
#>
function Get-FileSystemDrive
{
    Get-PSDrive 'D', 'C' -PSProvider 'FileSystem' -ErrorAction Ignore
}

function Confirm-PathIsContainer
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.DirectoryInfo])]
    param
    (
        [Parameter(Mandatory, Position = 0)]
        [Alias("PSPath")]
        [Alias("LiteralPath")]
        [string] $Path,

        [switch] $Force,

        [switch] $PassThru
    )

    $Result = Get-Item -Path:$Path -ErrorAction Ignore -Force:$Force
    if (!$Result)
    {
        $Result = mkdir -Path:$Path -ErrorAction Stop -Force:$Force -WhatIf:$WhatIfPreference
    }

    if ($PassThru)
    {
        return $Result
    }
}

<#
.SYNOPSIS
Gets the bootstrap-windows temp directory.
#>
function Get-BootstrapTempDirectory
{
    [OutputType([System.IO.DirectoryInfo])]
    param
    (
    )

    Confirm-PathIsContainer -LiteralPath (Join-Path $Env:TEMP 'bootstrap-windows') -PassThru
}