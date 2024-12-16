#Requires -Version 5
param()

Set-StrictMode -Version Latest

[char] $PLUS = '+'
[char] $MINUS = '-'
[char] $SOLIDUS = '/'
[char] $UNDERSCORE = '_'

function ConvertFrom-Base64Url
{
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    [OutputType([string])]
    param
    (
        [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $EncodedText,

        [switch] $AsByteArray
    )

    process
    {
        $PSBoundParameters.Remove('EncodedText')

        ConvertFrom-Base64 @PSBoundParameters -EncodedText ($EncodedText.Replace($MINUS, $PLUS).Replace($UNDERSCORE, $SOLIDUS))
    }
}

function ConvertTo-Base64Url
{
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    [OutputType([string])]
    param
    (
        [Parameter(ParameterSetName = "ByteArray", Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [byte[]] $ByteArray,

        [Parameter(ParameterSetName = "Text", Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Text,

        [switch] $InsertBreakLines
    )

    process
    {
        ConvertTo-Base64 @PSBoundParameters | ForEach-Object {
            $_.Replace($PLUS, $MINUS).Replace($SOLIDUS, $UNDERSCORE)
        }
    }
}