using namespace System
using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Immutable
using namespace System.Collections.Specialized
using namespace System.IO
using namespace System.Management.Automation
using namespace System.Text
using namespace System.Xml
using namespace System.Xml.Linq

Set-StrictMode -Version Latest

$utf8NoBom = [UTF8Encoding]::new($false)

[Type[]] $stringTypes = [string], [guid]

[Type[]] $integerTypes = [byte], [short], [int], [long], [sbyte], [ushort], [uint], [ulong]

[Type[]] $dateTypes = [datetime], [DateTimeOffset]
if ($PSEdition -eq 'Core')
{
    $dateTypes += [DateOnly], [TimeOnly]
}

[Type[]] $realTypes = [single], [double], [decimal]
if ($PSEdition -eq 'Core')
{
    $realTypes += [half]
}

# <dict> tag that are dictionaries (not psobject)
[Type[]] $dictDictionaryTypes = [hashtable], [OrderedDictionary], [IReadOnlyDictionary`2], [IDictionary`2]

[XElement] $xTrue = [XElement]::new([XName] 'true')
[XElement] $xFalse = [XElement]::new([XName] 'false')
[XElement] $xNil = [XElement]::new([XName] 'string')  # there isn't an explicit nil type
[XDocumentType] $doctype = [XDocumentType]::new('plist', '-//Apple//DTD PLIST 1.0//EN', 'http://www.apple.com/DTDs/PropertyList-1.0.dtd', [NullString]::Value)
[XAttribute] $attrPlistVersion = [XAttribute]::new('version', '1.0')

################################################################################

function ConvertFromElementToStringValue
{
    [CmdletBinding()]
    [OutputType([string])]
    [OutputType([NullString])]
    param([XmlElement] $element)

    if ($element.IsEmpty)
    {
        return [NullString]::Value
    }

    $result = $null

    $e = $element.get_ChildNodes().GetEnumerator()
    while ($e.MoveNext())
    {
        Write-Debug "node type: $($e.Current.NodeType)"
        switch ($e.Current.NodeType)
        {
            { $_ -eq [XmlNodeType]::Comment } { continue }

            { $_ -in [XmlNodeType]::Text, [XmlNodeType]::CDATA }
            {
                # This is content we want.
                if ($null -eq $result)
                {
                    # First value was found.
                    $result = $e.Current.Value
                }
                elseif ($result -is [string])
                {
                    # A second value was found.
                    $result = [List[string]] @($result, $e.Current.Value)
                }
                else
                {
                    # A third+ value was found.
                    $result.Add($e.Current.Value)
                }
            }

            default
            {
                Write-Error "Expected single text/cdata but got $_"
                return
            }
        }
    }

    if ($result -is [List[string]])
    {
        return $result -join ''
    }

    return $result ?? ''
}

function GetXmlNodePath([XmlNode] $node)
{
    $name = switch ($node.NodeType)
    {
        'Comment' { $node.Name }
        'Element' { $node.Name }
        'Text' { $node.Name }
        'CDATA' { $node.Name }

        default
        {
            '#' + $_.ToString().ToLowerInvariant()
        }
    }

    if ($node.ParentNode)
    {
        return (GetXmlNodePath $node.ParentNode) + '/' + $name
    }

    return $name
}

enum NextIs
{
    Key
    Value
}

<#
.SYNOPSIS
Converts XML to a custom object or a hash table.
#>
function ConvertFromPlistXmlElementRecursively
{
    [CmdletBinding()]
    [OutputType([byte[]])]
    [OutputType([bool])]
    [OutputType([DateTimeOffset])]
    [OutputType([double])]
    [OutputType([int])]
    [OutputType([ordered])]
    [OutputType([object[]])]
    [OutputType([long])]
    [OutputType([PSCustomObject])]
    [OutputType([string])]
    param
    (
        # Specifies the XML element.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNull()]
        [XmlElement] $Element,

        # Converts the XML to a hash table object. There are several scenarios where it can overcome some limitations of the `ConvertFrom-Xml` cmdlet.
        [switch] $AsHashtable,

        # The current depth.
        # NOTE: The "depth" measurement does not include the top-level object params, so in truth N levels is OK, N+1 is not.
        [Parameter()]
        [int] $Depth = -1,

        [Parameter(Mandatory)]
        [int] $MaxDepth
    )

    begin
    {
        if ($Depth -ge $MaxDepth)
        {
            $message = "Conversion from Plist failed with error: The reader's MaxDepth of ${MaxDepth} has been exceeded.  Path '$(GetXmlNodePath $Element)'"
            if ($Element -is [IXmlLineInfo])
            {
                $message += ", line $(1+$Element.LineNumber), position $(1+$Element.LinePosition)."
            }
            Write-Error -Category LimitsExceeded -Message $message
            return
        }

        $DepthLabel = $Depth -ge 0 ? ("  " * $Depth) + '|-' : ""
        $DepthPadding = $Depth -ge 0 ? ("  " * ($Depth+1)) : ""
    }

    process
    {
        $localName = $element.get_LocalName()

        if ($DebugPreference)
        {
            Write-Debug "${DepthLabel}[${localName}] $($element.OuterXml)"
        }

        # Return for scalars.
        switch -CaseSensitive ($localName)
        {
            'key' { return ConvertFromElementToStringValue $Element }
            'string' { return ConvertFromElementToStringValue $Element }
            'integer' { return [long] (ConvertFromElementToStringValue $Element) }
            'real' { return [double] (ConvertFromElementToStringValue $Element) }
            'true' { return $true }
            'false' { return $false }
            'date' { return [DateTimeOffset] (ConvertFromElementToStringValue $Element) }
            'data' { return [Convert]::FromBase64String((ConvertFromElementToStringValue $Element)) }

            # Not scalars, enumerate and evaluate all child elements.
            # Note array behavior is different!

            # plist root element behaves like array
            { $_ -cin 'array', 'plist' } {
                [object[]] $result = $element.get_ChildNodes() | Where-Object {
                    switch ($_.NodeType)
                    {
                        # Eat comments
                        'Comment' { $false }
                        # We want elements and nothing else.
                        'Element' { $true }
                        # oops.
                        default
                        {
                            Write-Error -Category NotImplemented -Message "unsupported child node type: $_"
                            continue
                        }
                    }
                } | ConvertFromPlistXmlElementRecursively -Depth:($Depth + 1) -MaxDepth:$MaxDepth -AsHashtable:$AsHashtable -ErrorAction:Stop
                write-debug "${DepthPadding}=> $($result -is [object[]]) [$(${result}?.GetType())] $($result | ConvertTO-Json -Depth 1 -Compress 3>$null)"
                Write-Output -NoEnumerate -InputObject $result
            }

            # Dictionary
            'dict'
            {
                Write-Verbose "dict: assemble key/value"
                $result = [ordered] @{ } # start with an ordered hashtable.

                # repeating child values: key, then value
                # Assume validated.
                $ChildDepth = $Depth + 1

                [NextIs] $nextIs = [NextIs]::Key
                $key = ''

                $e = $element.get_ChildNodes().GetEnumerator()
                while ($e.MoveNext())
                {
                    switch ($e.Current.NodeType)
                    {
                        # Eat comments
                        'Comment' { continue }

                        'Element'
                        {
                            [object] $value = ConvertFromPlistXmlElementRecursively -Element:$e.Current -Depth:$ChildDepth -MaxDepth:$MaxDepth -AsHashtable:$AsHashtable -ErrorAction:Stop
                            if ($nextIs -eq [NextIs]::Value)
                            {
                                write-debug "${DepthPadding}  add key=$key value=([$(${value}?.GetType())] $($value | ConvertTO-Json -Depth 1 -Compress 3>$null))"

                                $result.Add($key, $value)
                                $key = ''
                                $nextIs = [NextIs]::Key
                            }
                            else
                            {
                                write-debug "${DepthPadding}  key=$key"
                                $key = $value
                                $nextIs = [NextIs]::Value
                            }
                        }

                        # Just add the text
                        # 'Text'
                        # {
                        #     $childValues.Add($ChildNode.Value.Trim())
                        # }
                        # 'CDATA'
                        # {
                        #     $childValues.Add($ChildNode.Value.Trim())
                        # }

                        default
                        {
                            Write-Error -Category NotImplemented -Message "unsupported child node type: $_"
                            continue
                        }
                    }
                }

                # ConvertTo-Json bombs here because key is a dictionary?!?!?!
                # write-debug "${DepthPadding}=> [$($AsHashtable ? 'ordered' : 'PSCustomObject')] $($result | ConvertTO-Json -Depth 1 -Compress 3>$null)"
                return $AsHashtable ? $result : [PSCustomObject] $result
            }

            # Error
            default
            {
                Write-Error "unsupported element type: $_"
                return
            }
        }

    }
}

function ConvertToXmlDocument
{
    [OutputType([XmlDocument])]
    param
    (
        [Parameter(Mandatory)]
        [string] $InputObject
    )

    Write-Debug "ConvertToXml: $($InputObject)"

    # string will load if valid XML, everything else will error
    # NOTE: PowerShell's [xml] cast operator is looser than this, which is why we're doing it this way.
    try
    {
        $doc = [XmlDocument]::new()
        $doc.LoadXml($InputObject)
        return $doc
    }
    catch
    {
        Write-Error $_ -TargetObject $InputObject
        return
    }
}

function TryConvertToXmlDocument
{
    [CmdletBinding()]
    [OutputType([bool])]
    param
    (
        [Parameter(Mandatory)]
        [string] $InputObject,

        [Parameter(Mandatory)]
        [OutputType([XmlDocument])]
        [ref] $Document
    )

    # string will load if valid XML, everything else will error
    # NOTE: PowerShell's [xml] cast operator is looser than this, which is why we're doing it this way.
    $doc = [XmlDocument]::new()
    try
    {
        $doc.LoadXml($InputObject)
        $Document = $doc
        return $true
    }
    catch
    {
        return $false
    }
}

function ConvertFromPlistHelper
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [OutputType([hashtable])]
    param
    (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNull()]
        [XmlDocument] $Document
    )

    ConvertFromPlistXmlElementRecursively -Element:$Document.DocumentElement -MaxDepth:$Depth -AsHashtable:$AsHashtable
}

<#
.SYNOPSIS
Converts a plist-formatted string to a custom object or hash table.
#>
function ConvertFrom-Plist
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    [OutputType([hashtable])]
    param
    (
        # Specifies the plist strings to convert to plist objects.
        # Enter a variable that contains the string, or type a command or expression that gets the string. You can also pipe a string to `ConvertFrom-Plist`
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNull()]
        [AllowEmptyString()]
        [string] $InputObject,

        # Converts the plist to a hash table object. There are several scenarios where it can overcome some limitations of the `ConvertFrom-Plist` cmdlet.
        [switch] $AsHashtable,

        # Gets or sets the maximum depth the plist input is allowed to have. By default, it is 1024.
        [Parameter()]
        [ValidateRange('Positive')]
        [int] $Depth = 1024
    )

    begin
    {
        $_inputObjectBuffer = [List[string]]::new()
    }

    process
    {
        $_inputObjectBuffer.Add($InputObject)
    }

    end
    {
        # When Input is provided through pipeline, the input can be represented in the following two ways:
        # 1. Each input in the collection is a complete plist content. There can be multiple inputs of this format.
        # 2. The complete input is a collection which represents a single plist content. This is typically the majority of the case.
        Write-Debug "input buffer length: $($_inputObjectBuffer.Count)"
        switch ($_inputObjectBuffer.Count)
        {
            0 { <# Do nothing #> }
            1
            {
                # string will load if valid XML, everything else will error
                # NOTE: PowerShell's [xml] cast operator is looser than this, which is why we're doing it this way.
                $doc = ConvertToXmlDocument $InputObject
                ConvertFromPlistHelper -Document:$doc -MaxDepth:$Depth -AsHashtable:$AsHashtable
            }
            default
            {
                [ref] $refDoc = $null

                # Try to deserialize the first element.
                if (TryConvertToXmlDocument $_inputObjectBuffer[0] -Document $refDoc)
                {
                    # The first input string represents a complete plist content.
                    ConvertFromPlistHelper -Document:$refDoc.Value -MaxDepth:$Depth -AsHashtable:$AsHashtable
                    for ([int] $index = 1; $index -lt $_inputObjectBuffer.Count; $index++)
                    {
                        ConvertFromPlistHelper (ConvertToXmlDocument $_inputObjectBuffer[$index] -ErrorAction:Stop)
                    }
                }
                else
                {
                    # The first input string does not represent a complete plist content.
                    # Hence consider the the entire input as a single plist content.
                    ConvertFromPlistHelper (ConvertToXmlDocument ($_inputObjectBuffer -join [Environment]::NewLine))
                }
            }
        }
    }
}

<#
.SYNOPSIS
Converts custom object to a plist.
#>
function ConvertToPlistRecursively
{
    [CmdletBinding()]
    [OutputType([XElement])]
    param
    (
        # Specifies the XML strings or `XMLNode` to convert to PowerShell objects.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject,

        # The current depth.
        # NOTE: The "depth" measurement does not include the top-level object params, so in truth N levels is OK, N+1 is not.
        [Parameter()]
        [int] $Depth = -1,

        # The maximum depth.
        [Parameter(Mandatory)]
        [int] $MaxDepth,

        [Parameter(Mandatory)]
        [ref] $TotalDepthExceeded
    )

    begin
    {
        $DepthLabel = $Depth -ge 0 ? ("  " * $Depth) + '|-' : ""
        $DepthPadding = $Depth -ge 0 ? ("  " * ($Depth+1)) : ""
        $thisNodeDepthExceeded = $Depth -ge $MaxDepth
    }

    process
    {
        if ($DebugPreference)
        {
            Write-Debug "${DepthLabel}[$(${InputObject}?.GetType())] $(${InputObject} | ConvertTO-Json -depth 1 -compress 3>$null)"
        }

        if ($null -eq $InputObject)
        {
            # TODO unsure if this is right
            Write-Debug "${DepthPadding} => nil"
            return $xNil
        }

        if ($stringTypes | Where-Object { $InputObject -is $_ } | Select-Object -First 1)
        {
            Write-Debug "${DepthPadding} => string"
            return [XElement]::new('string', $InputObject)
        }

        if ($integerTypes | Where-Object { $InputObject -is $_ } | Select-Object -First 1)
        {
            Write-Debug "${DepthPadding} => integer"
            return [XElement]::new('integer', $InputObject)
        }

        if ($realTypes | Where-Object { $InputObject -is $_ } | Select-Object -First 1)
        {
            Write-Debug "${DepthPadding} => real"
            return [XElement]::new('real', $InputObject)
        }

        if ($InputObject -is [bool])
        {
            Write-Debug "${DepthPadding} => bool"
            return $InputObject ? $xTrue : $xFalse
        }

        if ($dateTypes | Where-Object { $InputObject -is $_ } | Select-Object -First 1)
        {
            Write-Debug "${DepthPadding} => date"
            return [XElement]::new('date', $InputObject.ToString('o'))
        }

        if ($InputObject -is [byte[]])
        {
            Write-Debug "${DepthPadding} => data"
            return [XElement]::new('data', [Convert]::ToBase64String($InputObject))
        }

        ## Depth check
        if ($thisNodeDepthExceeded)
        {
            Write-Debug "${DepthPadding} => maxdepth"
            $TotalDepthExceeded.Value = $true
            return [XElement]::new('string', $InputObject)
        }

        ## No recursion above this point!
        $ChildDepth = $Depth + 1

        if ($dictDictionaryTypes | Where-Object { $InputObject -is $_ } | Select-Object -First 1)
        {
            Write-Debug "${DepthPadding} => dict"
            $elements = foreach ($entry in $InputObject.GetEnumerator())
            {
                [XElement]::new('key', $entry.Key)
                ConvertToPlistRecursively -InputObject:($entry.Value) -Depth:$ChildDepth -MaxDepth:$MaxDepth -TotalDepthExceeded:$TotalDepthExceeded
            }
            return [XElement]::new('dict', $elements)
        }

        if ($InputObject -is [IEnumerable])
        {
            Write-Debug "${DepthPadding} => array"
            return [XElement]::new('array', ($InputObject | ConvertToPlistRecursively -Depth:$ChildDepth -MaxDepth:$MaxDepth -TotalDepthExceeded:$TotalDepthExceeded))
        }

        # PSObject: MUST be after hashtable and IEnumerable, because some hashtables get cycled into that.
        if ($InputObject -is [PSObject])
        {
            Write-Debug "${DepthPadding} => psobj:dict"
            $elements = foreach ($property in $InputObject.PSObject.Properties) # NOTE: this is the only way to get properties **IN ORDER**
            {
                [XElement]::new('key', $property.Name)
                ConvertToPlistRecursively $InputObject.$($property.Name) -Depth:$ChildDepth -MaxDepth:$MaxDepth -TotalDepthExceeded:$TotalDepthExceeded
            }
            return [XElement]::new('dict', $elements)
        }

        # Unknown
        Write-Error -Category NotImplemented -Message "For type: $(${InputObject}?.GetType() ?? '<null>')"
    }
}

<#
.SYNOPSIS
Converts an object to a Property List, or "plist".
#>
function ConvertTo-Plist
{
    [CmdletBinding()]
    [OutputType([string])]
    param
    (
        # Specifies the objects to convert to plist format. Enter a variable that contains the objects, or type a command or expression that gets the objects. You can also pipe an object to ConvertTo-Plist.
        #
        # The **InputObject** parameter is required, but its value can be null (`$null`) or an empty string. When the input object is `$null`, ConvertTo-Plist returns the plist representation of null. When the input object is an empty string, ConvertTo-Plist returns the plist representation of an empty string.
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [object] $InputObject,

        [int] $Depth = 10,

        # Omits white space and indented formatting in the output string.
        [switch] $Compress
    )

    begin
    {
        $saveOptions = $Compress ? [SaveOptions]::DisableFormatting : [SaveOptions]::None
        $encoding = $utf8NoBom

        filter XDocumentToString
        {
            # MSCRAP: XDocument.ToString() actively strips any <?xml?> declarations from the file;
            # to get one, we have to serialize to a stream.
            $stream = [MemoryStream]::new()
            $writer = [StreamWriter]::new($stream, $encoding)
            try
            {
                $_.Save($writer, $saveOptions)
                Write-Output $encoding.GetString($stream.ToArray())
            }
            finally
            {
                $writer.Dispose()
                $stream.Dispose()
            }
        }

        $warned = $false

        [XElement[]] $content = @()
    }

    process
    {
        [ref] $TotalDepthExceeded = $false
        $content +=  $InputObject | ConvertToPlistRecursively -MaxDepth:$Depth -TotalDepthExceeded $TotalDepthExceeded

        if ($TotalDepthExceeded.Value -and -not $warned)
        {
            Write-Warning "Resulting plist is truncated as serialization has exceeded the set depth of ${Depth}."
            $warned = $true
        }
    }

    end
    {
        # Must now embed in a "plist" top element
        [XDocument]::new(
            $doctype,
            [XElement]::new('plist', $attrPlistVersion, $content)
        ) | XDocumentToString
    }
}