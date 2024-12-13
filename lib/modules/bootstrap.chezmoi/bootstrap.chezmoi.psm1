#requires -version 7

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
    param
    ()
    Invoke-Chezmoi -Command 'data' --format json | ConvertFrom-Json
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
    param
    (
        [switch] $AsObject
    )

    $path = $Env:CHEZMOI_WORKING_TREE ?? (Get-ChezmoiData).chezmoi.workingTree

    if ($AsObject)
    {
        return Get-Item -LiteralPath:$path
    }


    $provider = $null
    $PSCmdlet.GetResolvedProviderPathFromPSPath($path, [ref] $provider)
}
