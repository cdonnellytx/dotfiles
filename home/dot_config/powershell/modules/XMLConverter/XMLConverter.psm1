using namespace System.Xml
using namespace Microsoft.PowerShell.Commands

param()

Set-StrictMode -Version Latest

# Do not return these, these are special processing attributes.
$SpecialAttributeNames = @(
    'xmlns'
)

<#
.SYNOPSIS
Converts XML to a custom object or a hash table.
#>
function ConvertFromXmlRecursively
{
    [CmdletBinding()]
    param
    (
        # Specifies the XML strings or `XMLNode` to convert to PowerShell objects.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [XmlNode] $Node,

        # Converts the XML to a hash table object. There are several scenarios where it can overcome some limitations of the `ConvertFrom-Xml` cmdlet.
        [switch] $AsHashtable,

        [Parameter(Mandatory)]
        [int] $Depth,

        [Parameter(Mandatory)]
        [int] $MaxDepth
    )

    begin
    {
        if ($Depth -eq 0)
        {
            Write-Warning "Resulting XML is truncated as serialization has exceeded the set depth of ${MaxDepth}."
            $Node
        }

        $ChildDepth = $Depth - 1
    }

    process
    {
        [XmlElement] $element = $null
        switch ($Node.NodeType)
        {
            # Eat comments.
            'Comment' { return }

            #  Just return the text
            'Text' { return $Node.Value.Trim() }
            'CDATA' { return $Node.Value.Trim() }

            # Document: map to Element
            'Document' { $element = $Node.DocumentElement }

            'Element' { $element = $Node } # The main thing to process, fall through

            'Attribute'
            {
                # Shouldn't be passed in recursion.
                Write-Error -Category InvalidOperation -Message "Unexpected node type: ${_}: $($node | Out-String)"
            }

            default
            {
                Write-Error -Category NotImplemented -Message "For node type: ${_}: $($node | Out-String)"
            }
        }

        Write-Verbose "calling with $($element.LocalName) depth=${Depth}/${MaxDepth}"

        # Scan attributes first, so we can ignore processing ones like "xmlns".
        # The order of elements is always significant regardless of what they are
        $oHash = [ordered] @{ } # start with an ordered hashtable.

        # record all the attributes first in the ordered hash
        foreach ($attribute in $element.Attributes)
        {
            if ($SpecialAttributeNames -cnotcontains $attribute.LocalName)
            {
                $oHash.Add($attribute.get_LocalName(), $attribute.Value)
            }
        }

        if ($oHash.Count -eq 0 -and !($element.ChildNodes | Where-Object NodeType -eq 'Element' | Select-Object -First 1))
        {
            # Element is empty OR only has text/cdata/comment.
            # Combine the text and join, and return as a string.
            return ($element.ChildNodes | ConvertFromXmlRecursively -Depth:$ChildDepth -MaxDepth:$MaxDepth -AsHashtable:$AsHashtable) -join ''
        }

        # Element contains at least one other element or attribute.  We will need to recurse.

        foreach ($child in $element.ChildNodes)
        {
            $childName = switch -CaseSensitive ($child.get_LocalName())
            {
                '#cdata-section' { 'Value' }
                '#text' { 'Value' }
                default { $_ }
            }
            $childValue = ConvertFromXmlRecursively -Node:$child -Depth:$ChildDepth -MaxDepth:$MaxDepth -AsHashtable:$AsHashtable

            if (!$oHash.Contains($childName))
            {
                $oHash.Add($childName, $childValue)
            }
            elseif ($oHash[$childName] -isnot [Array])
            {
                # Convert to array
                Write-Verbose "pseudo-Array ${childName}"
                $oHash[$childName] = @($oHash[$childName], $childValue)
            }
            else
            {
                # Already an array.
                $oHash[$childName] += $childValue
            }
        }

        if ($oHash.Count -eq 1)
        {
            # The entry is possibly a hashmap of name/value pairs.
            $entry = $oHash.GetEnumerator() | Select-Object -First 1
            if ($null -ne $entry.Value)
            {
                $ChildIsNotNameValue = $AsHashtable ? {
                    write-warning "_ is $($_.GetType()) $($_ | Out-String)"
                    return !($_.Count -eq 2 -and $_.Contains('Name') -and $_.Contains('Value'))
                } : {
                    [MemberDefinition[]] $props = Get-Member -InputObject $_ -MemberType NoteProperty
                    return !($props -and $props.Length -eq 2 -and $props[0].Name -ceq 'Name' -and $props[1].Name -ceq 'Value')
                }

                if ($entry.Value | Where-Object $ChildIsNotNameValue)
                {
                    # At least one property fails.
                    if ($VerbosePreference)
                    {
                        Write-Verbose "NOT possible hashmap candiadate: $($entry | Out-String)"
                    }
                }
                else
                {
                    # The entry is all namevalue pairs.
                    # Convert it to an ordered hashmap, then reassign the value (mapping to object if desired)
                    $childHash = [ordered] @{}
                    foreach ($e in $entry.Value)
                    {
                        $childHash.Add($e.Name, $e.Value)
                    }
                    $oHash[$entry.Name] = $AsHashtable ? $childHash : [PSCustomObject] $childHash
                }
            }
        }

        # Return the hashtable.
        return $AsHashtable ? $oHash : [PSCustomObject] $oHash
    }
}

function ConvertFrom-Xml
{
    [CmdletBinding()]
    param
    (
        # Specifies the XML strings or `XMLNode` to convert to PowerShell objects.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [object] $InputObject,

        # Converts the XML to a hash table object. There are several scenarios where it can overcome some limitations of the `ConvertFrom-Xml` cmdlet.
        [switch] $AsHashtable,

        [Parameter()]
        [ValidateRange(1, 100)]
        [int] $Depth = 10
    )

    process
    {
        [XmlNode] $node = if ($InputObject -is [XmlNode])
        {
            $InputObject
        }
        else
        {
            # string will convert if valid XML, everything else will error
            try
            {
                ([xml] $InputObject)
            }
            catch
            {
                Write-Error $_
                return
            }
        }

        ConvertFromXmlRecursively -Node:$node -Depth:$Depth -MaxDepth:$Depth -AsHashtable:$AsHashtable
    }
}

