using namespace System
using namespace System.Collections
using namespace System.Globalization
using namespace System.Text

using module Pansies
using namespace PoshCode.Pansies
using namespace PoshCode.Pansies.ColorSpaces

param()

Set-StrictMode -Version Latest

filter ToRgbColor
{
    [RgbColor] $_
}

<#
.SYNOPSIS
Gets the given color as RGB.
#>
function Get-RgbColor
{
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([PoshCode.Pansies.RgbColor])]
    param
    (
        # The color name or RGB code.
        [Parameter(ParameterSetName = 'String', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        # The color object.
        [Parameter(ParameterSetName = 'Object', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ColorSpace] $InputObject,

        # The red value.
        [Parameter(ParameterSetName = 'RGB', Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('R')]
        [int] $Red,

        # The green value.
        [Parameter(ParameterSetName = 'RGB', Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('G')]
        [int] $Green,

        # The blue value.
        [Parameter(ParameterSetName = 'RGB', Position = 2, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('B')]
        [int] $Blue
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'String'
            {
                $Color | ToRgbColor
            }

            'RGB'
            {
                [RgbColor]::new($Red, $Green, $Blue)
            }

            'Object'
            {
                [RgbColor] $InputObject
            }

            default
            {
                Write-Error -Category NotImplemented -Message "For parameter set `"$($PSCmdlet.ParameterSetName)`""
            }
        }
    }
}

<#
.SYNOPSIS
Gets the given color as BGR.
#>
function Get-BgrColor
{
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([PoshCode.Pansies.RgbColor])] # there is no BgrColor type in Pansies
    param
    (
        # The color name or BGR code.
        [Parameter(ParameterSetName = 'String', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        # The color object.
        [Parameter(ParameterSetName = 'Object', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ColorSpace] $InputObject,

        # The blue value.
        [Parameter(ParameterSetName = 'BGR', Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('B')]
        [int] $Blue,

        # The green value.
        [Parameter(ParameterSetName = 'BGR', Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('G')]
        [int] $Green,

        # The red value.
        [Parameter(ParameterSetName = 'BGR', Position = 2, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('R')]
        [int] $Red
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'String'
            {
                [RgbColor]::FromRgb(($Color | ToRgbColor).BGR)
            }

            'BGR'
            {
                [RgbColor]::new($Red, $Green, $Blue)
            }

            'Object'
            {
                [RgbColor]::FromRgb(([RgbColor] $InputObject).BGR)
            }

            default
            {
                Write-Error -Category NotImplemented -Message "For parameter set `"$($PSCmdlet.ParameterSetName)`""
            }
        }
    }
}

<#
.SYNOPSIS
Gets the given color as HSB.
#>
function Get-HsbColor
{
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([PoshCode.Pansies.HsbColor])]
    param
    (
        # The color name or RGB code.
        [Parameter(ParameterSetName = 'String', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        # The color object.
        [Parameter(ParameterSetName = 'Object', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ColorSpace] $InputObject,

        # The brightness value.
        [Parameter(ParameterSetName = 'HSB', Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('H')]
        [int] $Hue,

        # The brightness value.
        [Parameter(ParameterSetName = 'HSB', Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 1)]
        [Alias('S')]
        [double] $Saturation,

        # The brightness value.
        [Parameter(ParameterSetName = 'HSB', Position = 2, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 1)]
        [Alias('B')]
        [Alias('Value')]
        [Alias('V')]
        [double] $Brightness
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'String'
            {
                [HsbColor] ($Color | ToRgbColor)
            }

            'HSB'
            {
                [HsbColor] @{ H = $Hue; S = $Saturation; B = $Brightness }
            }

            'Object'
            {
                [HsbColor] $InputObject
            }

            default
            {
                Write-Error -Category NotImplemented -Message "For parameter set `"$($PSCmdlet.ParameterSetName)`""
            }
        }
    }
}

function ConvertTo-AnsiSequence
{
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([string])]
    param
    (
        # The color name, RGB code, or ANSI sequence.
        [Parameter(ParameterSetName = 'String', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        # The color object.
        [Parameter(ParameterSetName = 'Object', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ColorSpace] $InputObject,

        # When set to true, the color will be converted to a background ANSI sequence.
        [Parameter(ParameterSetName = '*')]
        [switch] $Background,

        # Controls the ANSI conversion behavior.
        [Parameter(ParameterSetName = '*')]
        [ColorMode] $Mode = [ColorMode]::Automatic
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'String'
            {
                switch -regex ($Color)
                {
                    "(?!i)^\u001b\[.*m$"
                    {
                        # It's already an ANSI sequence.
                        return $Color
                    }
                    default
                    {
                        # Convert to RgbColor, then to ANSI sequence.
                        ($Color | ToRgbColor).ToVtEscapeSequence($Background, $Mode)
                    }
                }
            }

            'Object'
            {
                # Convert to RgbColor, then to ANSI sequence.
                ([RgbColor] $InputObject).ToVtEscapeSequence($Background, $Mode)
            }

            default
            {
                Write-Error -Category NotImplemented -Message "For parameter set `"$($PSCmdlet.ParameterSetName)`""
            }
        }
    }
}

# https://en.wikipedia.org/wiki/HSL_and_HSV
New-Alias -Name 'Get-HsvColor' -Value 'Get-HsbColor'

function ConvertToAlpha([string] $Value)
{
    return [int]::Parse($Value, [NumberStyles]::HexNumber) / 255
}

class AlphaRgbColorBase : RgbColor
{
    [ValidateRange(0, 1)]
    [double] $Alpha = 1

    AlphaRgbColorBase([string] $Color) : base($this.GetRgbString($Color))
    {
        if ($alphaString = $this.GetAlphaString($Color))
        {
            $this.Alpha = [int]::Parse($alphaString, [NumberStyles]::HexNumber) / 255
        }
    }

    AlphaRgbColorBase([RgbColor] $Color) : base($Color)
    {
        if ($Color -is [AlphaRgbColorBase])
        {
            $this.Alpha = $Color.Alpha
        }
    }

    AlphaRgbColorBase([AlphaRgbColorBase] $Color) : base($Color)
    {
        $this.Alpha = $Color.Alpha
    }

    AlphaRgbColorBase([double] $Alpha, [RgbColor] $Color) : base($Color)
    {
        $this.Alpha = $Alpha
    }

    AlphaRgbColorBase([int] $Red, [int] $Green, [int] $Blue, [double] $Alpha) : base($Red, $Green, $Blue)
    {
        $this.Alpha = $Alpha
    }
    [int] GetARGB()
    {
        $alpha255 = [int] ($this.Alpha * 255)
        return ($alpha255 -shl 24) + $this.RGB
    }

    [int] GetRGBA()
    {
        $alpha255 = [int] ($this.Alpha * 255)
        return $this.RGB -shl 8 + $alpha255
    }

    [RgbColor] Blend([RgbColor] $Background)
    {
        switch ($this.Alpha)
        {
            1 { return $this }
            0 { return $Background }
        }

        # Fetch the background alpha to properly combine
        $BackgroundAlpha = if ($Background -is [AlphaRgbColorBase]) { $Background.Alpha } else { 1 }

        $ThisMultiplier = $BackgroundAlpha * $this.Alpha
        $BackgroundMultiplier = 1 - $this.Alpha
        return [RgbColor]::new(
            $ThisMultiplier * $this.R + $BackgroundMultiplier * $Background.R,
            $ThisMultiplier * $this.G + $BackgroundMultiplier * $Background.G,
            $ThisMultiplier * $this.B + $BackgroundMultiplier * $Background.B
        )
    }

    hidden [string] GetRgbString([string] $Color) { throw [NotImplementedException]::new() }

    hidden [string] GetAlphaString([string] $Color) { throw [NotImplementedException]::new() }
}

class ArgbColor : AlphaRgbColorBase
{
    ArgbColor([string] $Color) : base($Color) { }
    ArgbColor([RgbColor] $Color) : base($Color) { }
    ArgbColor([double] $Alpha, [RgbColor] $Color) : base($Alpha, $Color) { }
    ArgbColor([double] $Alpha, [int] $Red, [int] $Green, [int] $Blue) : base($Red, $Green, $Blue, $Alpha) { }

    [string] ToString()
    {
        return '#{0:X8}' -f $this.GetARGB()
    }

    static [ArgbColor] ConvertFrom([object] $InputData)
    {
        if ($InputData -is [ArgbColor])
        {
            return $InputData
        }

        return [ArgbColor]::new($InputData)
    }

    hidden [string] GetRgbString([string] $Color)
    {
        $Color = $Color.TrimStart('#')

        switch ($Color.Length)
        {
            3 { return $Color -creplace '(.)', '$1$1' }
            4 { return $Color.Substring(1) -creplace '(.)', '$1$1' }
            6 { return $Color }
            8 { return $Color.Substring(2) }
        }
        throw [ArgumentOutOfRangeException]::new('Color', $Color, 'Invalid length')
    }

    hidden [string] GetAlphaString([string] $Color)
    {
        $Color = $Color.TrimStart('#')

        switch ($Color.Length)
        {
            3 { return '' }
            4 { return '{0}{0}' -f $Color.Substring(0, 1) }
            6 { return '' }
            8 { return $Color.Substring(0, 2) }
        }
        throw [System.ArgumentOutOfRangeException]::new('Color', $Color, 'Invalid length')
    }
}

class RgbaColor : AlphaRgbColorBase
{
    RgbaColor([string] $Color) : base($Color) { }
    RgbaColor([RgbColor] $Color) : base($Color) { }
    RgbaColor([double] $Alpha, [RgbColor] $Color) : base($Alpha, $Color) { }
    RgbaColor([int] $Red, [int] $Green, [int] $Blue, [double] $Alpha) : base($Red, $Green, $Blue, $Alpha) { }

    [string] ToString()
    {
        return '#{0:X8}' -f $this.GetRGBA()
    }

    static [RgbaColor] ConvertFrom([object] $InputData)
    {
        if ($InputData -is [RgbaColor])
        {
            return $InputData
        }

        return [RgbaColor]::new($InputData)
    }

    hidden [string] GetRgbString([string] $Color)
    {
        $Color = $Color.TrimStart('#')

        switch ($Color.Length)
        {
            3 { return $Color -creplace '(.)', '$1$1' }
            4 { return $Color.Substring(0, 3) -creplace '(.)', '$1$1' }
            6 { return $Color }
            8 { return $Color.Substring(0, 6) }
        }
        throw [ArgumentOutOfRangeException]::new('Color', $Color, 'Invalid length')
    }

    hidden [string] GetAlphaString([string] $Color)
    {
        $Color = $Color.TrimStart('#')

        switch ($Color.Length)
        {
            3 { return '' }
            4 { return '{0}{0}' -f $Color.Substring(3, 1) }
            6 { return '' }
            8 { return $Color.Substring(6, 2) }
        }
        throw [System.ArgumentOutOfRangeException]::new('Color', $Color, 'Invalid length')
    }
}

<#
.SYNOPSIS
Gets the ARGB color.
#>
function Get-ArgbColor
{
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([ArgbColor])]
    param
    (
        # The color name or RGB code.
        [Parameter(ParameterSetName = 'String', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        # The color object.
        [Parameter(ParameterSetName = 'Object', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ColorSpace] $InputObject,

        # The alpha channel.
        [Parameter(ParameterSetName = 'ARGB', Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 1)]
        [Alias('A')]
        [double] $Alpha,

        # The red value.
        [Parameter(ParameterSetName = 'ARGB', Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('R')]
        [int] $Red,

        # The green value.
        [Parameter(ParameterSetName = 'ARGB', Position = 2, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('G')]
        [int] $Green,

        # The blue value.
        [Parameter(ParameterSetName = 'ARGB', Position = 3, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('B')]
        [int] $Blue
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'String' { [ArgbColor]::new($Color) }
            'ARGB' { [ArgbColor]::new($Alpha, $Red, $Green, $Blue) }
            'Object' { [ArgbColor]::ConvertFrom($InputObject) }

            default
            {
                Write-Error -Category NotImplemented -Message "For parameter set `"$($PSCmdlet.ParameterSetName)`""
            }
        }
    }
}

<#
.SYNOPSIS
Gets the RGBA color.
#>
function Get-RgbaColor
{
    [CmdletBinding(DefaultParameterSetName = 'String')]
    [OutputType([RgbaColor])]
    param
    (
        # The color name or RGB code.
        [Parameter(ParameterSetName = 'String', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $Color,

        # The color object.
        [Parameter(ParameterSetName = 'Object', Position = 0, Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ColorSpace] $InputObject,

        # The red value.
        [Parameter(ParameterSetName = 'RGBA', Position = 0, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('R')]
        [int] $Red,

        # The green value.
        [Parameter(ParameterSetName = 'RGBA', Position = 1, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('G')]
        [int] $Green,

        # The blue value.
        [Parameter(ParameterSetName = 'RGBA', Position = 2, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 255)]
        [Alias('B')]
        [int] $Blue,

        # The alpha channel.
        [Parameter(ParameterSetName = 'RGBA', Position = 3, Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateRange(0, 1)]
        [Alias('A')]
        [double] $Alpha
    )

    process
    {
        switch ($PSCmdlet.ParameterSetName)
        {
            'String' { [RgbaColor]::new($Color) }
            'RGBA' { [RgbaColor]::new($Red, $Green, $Blue, $Alpha) }
            'Object' { [RgbaColor]::ConvertFrom($InputObject) }

            default
            {
                Write-Error -Category NotImplemented -Message "For parameter set `"$($PSCmdlet.ParameterSetName)`""
            }
        }
    }
}