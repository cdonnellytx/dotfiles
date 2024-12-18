using namespace System
using namespace System.Collections.Generic
using namespace System.IO

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Invokes Chezmoi.
#>
function Invoke-Chezmoi
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [string] $Command,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]] $Arguments,

        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )

    begin
    {
        $chezmoi = Get-Command -Name ($Env:CHEZMOI_EXECUTABLE ?? 'chezmoi') -ErrorAction Stop
        $buffer = [List[object]]::new()
    }

    process
    {
        $buffer.Add($InputObject)
    }

    end
    {
        if (!$PSCmdlet.ShouldProcess("path: $($chezmoi.Source), arguments: $($arguments | ConvertTo-Json -Compress)", "Invoke chezmoi"))
        {
            return
        }

        if ($buffer.Count)
        {
            $buffer | & $chezmoi $Command @Arguments
        }
        else
        {
            & $chezmoi $Command @Arguments
        }
    }
}

<#
.SYNOPSIS
`chezmoi data` as a PowerShell object.
#>
function Get-ChezmoiData
{
    [CmdletBinding()]
    [OutputType([PSObject])]
    param()

    Invoke-Chezmoi -Command 'data' --format json | ConvertFrom-Json
}

filter ToPath([switch] $AsObject)
{
    if ($AsObject)
    {
        return Get-Item -LiteralPath:$_
    }

    $provider = $null
    return $PSCmdlet.GetResolvedProviderPathFromPSPath($_, [ref] $provider)
}

<#
.SYNOPSIS
Gets the Chezmoi home directory.
#>
function Get-ChezmoiHomeDir
{
    [CmdletBinding()]
    [OutputType([string])]
    [OutputType([IO.DirectoryInfo])]
    param([switch] $AsObject)

    $Env:CHEZMOI_HOME_DIR ?? (Get-ChezmoiData).chezmoi.homeDir | ToPath -AsObject:$AsObject
}
<#
.SYNOPSIS
Gets the Chezmoi source directory.
#>
function Get-ChezmoiSourceDir
{
    [CmdletBinding()]
    [OutputType([string])]
    [OutputType([IO.DirectoryInfo])]
    param([switch] $AsObject)

    $Env:CHEZMOI_SOURCE_DIR ?? (Get-ChezmoiData).chezmoi.sourceDir | ToPath -AsObject:$AsObject
}

<#
.SYNOPSIS
Gets the Chezmoi working tree.
#>
function Get-ChezmoiWorkingTree
{
    [CmdletBinding()]
    [OutputType([string])]
    [OutputType([IO.DirectoryInfo])]
    param([switch] $AsObject)

    $Env:CHEZMOI_WORKING_TREE ?? (Get-ChezmoiData).chezmoi.workingTree | ToPath -AsObject:$AsObject
}

function Invoke-ChezmoiTemplate
{
    [CmdletBinding(DefaultParameterSetName = 'Input')]
    param
    (
        # The input object.
        [Parameter(ParameterSetName = 'Input', Position = 0, Mandatory, ValueFromPipeline)]
        [string] $InputObject,

        # The path to the script to invoke.
        [Parameter(ParameterSetName = 'FilePath', Position = 0, Mandatory)]
        [string] $FilePath,

        # Write output to path instead of stdout
        [Parameter()]
        [string] $OutFile

    )

    begin
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Input'
            {
                $buffer = [List[string]]::new()
            }
        }
    }

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'Input'
            {
                $buffer.Add($InputObject)
            }
        }
    }

    end
    {
        [string] $text = switch ($PSCmdlet.ParameterSetName)
        {
            'Input'
            {
                $buffer -join [Environment]::NewLine
            }
            'FilePath'
            {
                Get-Content -LiteralPath:$FilePath -Raw -ErrorAction Stop
            }
            default
            {
                Write-Error -Category NotImplemented "For parameter set: '${_}'"
            }
        }

        [string[]] $arguments = @()
        if ($OutFile)
        {
            $arguments += '--output', $OutFile
        }

        $text | Invoke-Chezmoi execute-template @arguments
    }
}
