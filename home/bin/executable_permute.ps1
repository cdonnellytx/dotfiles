param
(
    [Parameter(ValueFromRemainingArguments, Position=0, Mandatory)]
    [decimal[]] $InputObject
)

class Permutation
{
    static hidden [hashtable[]] $MemberDefinitions = @(
        @{
            MemberName = 'Signs'
            MemberType = 'ScriptProperty'
            Value = { $this.GetSigns() }
        }
    )

    static Permutation() {
        [Permutation]::MemberDefinitions | % { Update-TypeData -TypeName 'Permutation' @_ }
    }

    [decimal] $Sum
    [decimal[]] $Items

    hidden [string] GetSigns()
    {
        return ($this.Items | % {
            switch ([Math]::Sign($_))
            {
                0 { ' ' }
                1 { '+' }
                -1 { '-' }
            }
        }) -join ''
    }
}

function permute
{
    param
    (
        [decimal[]] $array,
        [int] $index = 0
    )

    $value = $array[$index]

    switch ($array.length - $index)
    {
        { $_ -lt 0 } { throw "oops $index $($array.length)" }

        0
        {
            [Permutation] @{
                Items = @()
                Sum = 0
            }
        }

        default
        {
            permute $array ($index+1) | % {
                [Permutation] @{
                    Items = @($Value) + $_.Items
                    Sum = $Value + $_.Sum
                }
                if ($Value -ne 0) {
                    [Permutation] @{
                        Items = @(-$Value) + $_.Items
                        Sum = -$Value + $_.Sum
                    }
                }
            }
        }
    }
}

permute $InputObject
