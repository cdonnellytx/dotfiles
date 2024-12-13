#requires -version 7.0

using namespace System.Collections.Generic
using namespace System.IO
using namespace Microsoft.Win32

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Gets the registry entry, or creates it if not found, and ensures it has the given value.
#>
function Confirm-RegistryEntry
{
    [CmdletBinding(SupportsShouldProcess)]
    param
    (
        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        # Specifies the name of the registry entry.
        [Parameter(Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Name,

        # Specifies the type of property that this cmdlet adds.
        [Parameter(ValueFromPipelineByPropertyName)]
        [Alias("Type")]
        [Nullable[Microsoft.Win32.RegistryValueKind]] $PropertyType,

        #  Specifies the value of the entry.
        [Parameter(Position = 2, ValueFromPipelineByPropertyName)]
        [object] $Value,

        # Returns an object that represents the registry entry. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    process
    {
        Confirm-RegistryPath -LiteralPath:$LiteralPath -PassThru | ForEach-Object {
            if ($_ | Get-ItemProperty -Name $Name -ErrorAction Ignore)
            {
                $_ | Set-ItemProperty -Name $Name -Value $Value -PassThru:$PassThru
            }
            else
            {
                $pt = $PropertyType
                if ($null -eq $pt)
                {
                    $pt = if ($Value -is [int]) { [RegistryValueKind]::DWord } else { [RegistryValueKind]::String }
                }

                $result = $_ | New-ItemProperty -Name $Name -Value $Value -PropertyType $pt
                if ($PassThru)
                {
                    return $result
                }
            }
        }
    }
}

<#
.SYNOPSIS
Gets the registry paths, or creates them if not found.
#>
function Confirm-RegistryPath
{
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([Microsoft.Win32.RegistryKey])]
    param
    (
        # Specifies a path to one or more locations. Unlike the Path parameter, the value of the LiteralPath parameter is
        # used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters,
        # enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any
        # characters as escape sequences.
        [Parameter(Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Path")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]] $LiteralPath,

        # Returns an object that represents the registry key. By default, this cmdlet does not generate any output.
        [switch] $PassThru
    )

    process
    {
        $LiteralPath |
            ForEach-Object {
                if ($result = Get-Item -ErrorAction Ignore -LiteralPath $_)
                {
                    return $result
                }

                # MSCRAP: mkdir doesn't create a tree structure in the registry provider.
                # So we have to crawl parents ourselves, and create the parents as needed.

                $selfOrAncestors = [Stack[string]]::new()

                for ($item = $_; $item; $item = Split-Path $item)
                {
                    if (Test-Path -LiteralPath $item)
                    {
                        break
                    }
                    $selfOrAncestors.Push($item)
                }

                # Now create the keys, returning the one the user wants.
                while ($selfOrAncestors.TryPop([ref] $item))
                {
                    $result = New-Item -Path $item
                }

                if ($PassThru)
                {
                    return $result
                }
            }
    }
}

