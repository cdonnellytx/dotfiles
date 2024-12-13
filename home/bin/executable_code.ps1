#!/usr/bin/env -S pwsh -NoProfile
[CmdletBinding(DefaultParameterSetName = 'Path')]
param
(
    [Parameter(ParameterSetName = 'Path', Position = 0, Mandatory, ValueFromPipeline, ValueFromRemainingArguments)]
    [ValidateNotNullOrEmpty()]
    [string[]] $Path,

    [Parameter(ParameterSetName = 'LiteralPath', Mandatory, ValueFromPipelineByPropertyName)]
    [Alias('PSPath')]
    [ValidateNotNullOrEmpty()]
    [string[]] $LiteralPath
)

begin
{
    # Ensure code exists, and is not itself a PowerShell script.
    $code = Get-Command -Name Code -Type Application -ErrorAction Stop | Select-Object -First 1
}

process
{
    [string[]] $ResolvedPaths = switch ($PSCmdlet.ParameterSetName)
    {
        'Path' { Get-Item -Path:$Path -ErrorAction Stop }
        'LiteralPath' { $LiteralPath }
    }

    & $code $ResolvedPaths
}
