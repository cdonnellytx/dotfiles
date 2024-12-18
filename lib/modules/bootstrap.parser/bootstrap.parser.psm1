using namespace System.Collections.Generic
using namespace System.IO
using namespace Microsoft.Win32

Set-StrictMode -Version Latest

class Column
{
    [string] $Name
    [int] $StartIndex
    [Nullable[int]] $Length
}

filter MapColumns
{
    begin
    {
        [int] $StartIndex = 0
        $columns = [List[Column]]::new()
    }

    process
    {
        [Column] $column = if ($_ -is [string])
        {
            [Column] @{
                Name = $_.Trim()
                StartIndex = $StartIndex
                Length = $_.Length
            }
        }
        else
        {
            $_
        }

        $StartIndex += $column.Length
        $columns.Add($column)
    }

    end
    {
        if ($columns.Count)
        {
            $columns[-1].Length = $null
        }

        return $columns
    }
}

<#
.SYNOPSIS
Gets the registry entry, or creates it if not found, and ensures it has the given value.
#>
function ConvertFrom-FixedWidth
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param
    (
        # Specifies the strings to be converted to objects.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string] $InputObject,

        # Specifies an alternate column header row for the imported string.
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [PSObject[]] $Header
    )

    begin
    {
        # This does a reasonable job of getting the data into object form, but is probably fragile.
        [List[Column]] $columns = $null

        if ($Header)
        {
            $columns = $Header | MapColumns
        }

    }

    process
    {
        if ($null -eq $columns)
        {
            if ($InputObject -cmatch '\S')
            {
                $columns = $InputObject -csplit "(?<=\S +)(?=\S)" | MapColumns

                iF ($VerbosePreference)
                {
                    Write-Verbose "first content line: $(ConvertTo-Json $InputObject) => $(ConvertTo-Json $columns)"
                }

                if ($columns.Count -eq 0)
                {
                    Write-Error -Category InvalidData -Message 'No headers specified, and first line does not contain any data.'
                }
            }

            return
        }


        switch -regex ($InputObject)
        {
            '^-+$' { } # swallow delimiter
            default
            {
                $hash = @{}

                $lastColumn = $columns.Count - 1
                for ($i = 0; $i -lt $lastColumn; $i++)
                {
                    $column = $Columns[$i]
                    $hash.Add($column.Name, $_.Substring($column.StartIndex, $column.Length).TrimEnd())
                }

                $column = $Columns[-1]
                $hash.Add($column.Name, $_.Substring($column.StartIndex).TrimEnd())

                Write-Output ([PSCustomObject] $hash)
            }
        }

    }
}
