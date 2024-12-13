#!/usr/bin/env -S pwsh -NoProfile
#Requires -Version 5
# Author: Todd Larason <jtl@molehill.org>
# $XFree86: xc/programs/xterm/vttests/256colors2.pl,v 1.2 2002/03/26 01:46:43 dickey Exp $

# use the resources for colors 0-15 - usually more-or-less a
# reproduction of the standard ANSI colors, but possibly more
# pleasing shades

Using Namespace System.Text

[CmdletBinding()]
param
(
    # The width of the true color swatch to print.
    [Parameter()]
    [int] $Width = $Host.UI.RawUI.WindowSize.Width
)

Set-StrictMode -Version Latest

$CSI = [char]0x1b

$ColorReset = "${CSI}[0m"

function Write-Text
{
    param
    (
        [Parameter(Mandatory)]
        [StringBuilder] $builder,

        [Parameter()]
        [string] $Value
    )

    $builder.Append($value) > $null
}

function Write-Line
{
    param
    (
        [Parameter(Mandatory)]
        [StringBuilder] $builder,

        [Parameter()]
        [string] $Value
    )

    $builder.Append($ColorReset).AppendLine($Value) > $null
}

function Write-ColorReset
{
    param
    (
        [Parameter(Mandatory)]
        [StringBuilder] $builder
    )

    Write-Text $builder $ColorReset
}

function Write-256ColorSwatch
{
    param
    (
        [Parameter(Mandatory)]
        [StringBuilder] $builder,

        [Parameter(Mandatory)]
        [int] $Color
    )

    Write-Text $builder "${CSI}[48;5;${Color}m  "
}

function Write-SystemColors
{
    $sb = [StringBuilder]::new(1024)
    Write-Line $sb "System colors:"

    foreach ($color in 0..7)
    {
        Write-256ColorSwatch $sb $color
    }
    Write-Line $sb

    foreach ($color in 8..15)
    {
        Write-256ColorSwatch $sb $color
    }
    Write-Line $sb

    return $sb.ToString()
}

# colors 16-231 are a 6x6x6 color cube
function Write-256Colors
{
    $sb = [StringBuilder]::new(1024)
    Write-Line $sb "Color cube, 6x6x6:"

    for ($green = 0; $green -lt 6; $green++) {
        for ($red = 0; $red -lt 6; $red++) {
            for ($blue = 0; $blue -lt 6; $blue++) {
                $color = 16 + ($red * 36) + ($green * 6) + $blue;
                Write-256ColorSwatch $sb $color
            }
            Write-ColorReset $sb
        }
        Write-Line $sb
    }
    return $sb.ToString()
}

function Write-TrueColor
{
    [OutputType([string])]
    param([int] $Width)

    $sb = [StringBuilder]::new(1024)
    Write-Line $sb "True color test:"

    $str = '/\'

    foreach ($colnum in 0..(${Width}-1))
    {
        [int] $r = 255 - ($colnum * 255 / $Width)
        [int] $g = ($colnum*510/$Width)
        [int] $b = ($colnum*255/$Width)
        if ($g -gt 255) { $g = 510-$g }

        $bg = "${CSI}[48;2;${r};${g};${b}m"
        $fg = "${CSI}[38;2;$(255-$r);$(255-$g);$(255-$b)m"

        $sb.Append($bg).
            Append($fg).
            Append($str[$colnum % $str.Length]).
            Append($ColorReset) > $null
    }

    $sb.ToString()
}

# colors 232-255 are a grayscale ramp, intentionally leaving out
# black and white
function Write-Grayscale
{
    [OutputType([string])]
    param()

    $sb = [StringBuilder]::new(1024)

    Write-Line $sb "Grayscale ramp:";
    for ($color = 232; $color -lt 256; $color++) {
        Write-256ColorSwatch $sb $color
    }
    Write-ColorReset $sb
    Write-Line $sb

    return $sb.ToString()
}

# display the colors
Write-SystemColors
Write-256Colors
Write-Grayscale

Write-TrueColor -Width $Width