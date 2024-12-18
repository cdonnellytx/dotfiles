using namespace System.IO

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

    $Result = Get-Item -Path:$Path -ErrorAction:Ignore -Force:$Force
    if (!$Result)
    {
        $Result = New-Item -Path:$Path -ItemType:Directory -ErrorAction:Stop -Force:$Force -WhatIf:$WhatIfPreference
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

    Confirm-PathIsContainer -LiteralPath (Join-Path $Env:TEMP 'bootstrap-dotfiles') -PassThru
}

<#
.SYNOPSIS
Creates a temporary directory which should be cleaned up later.
#>
function New-TemporaryDirectory
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.DirectoryInfo])]
    param()

    if (!$PSCmdlet.ShouldProcess([Path]::GetTempPath(), "New-TemporaryDirectory"))
    {
        return $null
    }

    # MSCRAP: Can't generate a unique temp file name without it creating the file.
    $tmpFile = New-TemporaryFile
    $tmpFullName = $tmpFile.FullName
    $tmpFile.Delete()

    New-Item -Path $tmpFullName -ItemType:Directory -WhatIf:$WhatIfPreference
}
