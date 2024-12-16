Using Namespace System.Management.Automation
Using Namespace System.Management.Automation.Language
Using Namespace Microsoft.PowerShell

#Requires -Version 5

Set-StrictMode -Version Latest

# Default value of MaximumHistoryCount, which is intrinsic to PowerShell and used by PSReadline, is 4096 as of 3.0.
# Maximum is 32K per the following command:
#
#       Get-Variable MaximumHistoryCount | % Attributes | ? { $_.TypeId -eq [System.Management.Automation.ValidateRangeAttribute] } | % MaxRange
#
# 32K seems excessive though, and may cause slowdown.  Setting to a more reasonable value.
$Global:MaximumHistoryCount = 8192

if (!(Get-Module PSReadline -ErrorAction Ignore))
{
    Write-Verbose "Skipping PSReadline configuration: not found"
    return
}

#region Options

$option = Get-PSReadLineOption

# PowerShell 6 defaults to Emacs mode on Unix (which is what bash defaults to).
# We want Windows-like handling -- but with some of the Emacs-y keys (e.g. Ctrl+D)
$option.EditMode = [EditMode]::Windows

# History: no dups, limit count.
$option.MaximumHistoryCount = $Global:MaximumHistoryCount
$option.HistoryNoDuplicates = $true

#endregion Options

#region Key Handlers

#region Windows fixes

if ($IsWindows)
{
    # bash/emacs-style key handlers (only missing on Windows)
    # EditMode::Windows has this on macOS/Linux.
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

    # Ctrl+Insert to go with Shift+Insert.
    # No idea why they didn't include this one :shrug:
    Set-PSReadLineKeyHandler -Key Ctrl+Insert -Function Copy
}

#endregion Windows fixes

#region Smart Insert/Delete
# source: https://raw.githubusercontent.com/PowerShell/PSReadLine/master/PSReadLine/SamplePSReadLineProfile.ps1

# The next four key handlers are designed to make entering matched quotes
# parens, and braces a nicer experience.  I'd like to include functions
# in the module that do this, but this implementation still isn't as smart
# as ReSharper, so I'm just providing it as a sample.

Set-PSReadLineKeyHandler -Key '"', "'" `
    -BriefDescription SmartInsertQuote `
    -LongDescription "Insert paired quotes if not already on a quote" `
    -ScriptBlock {
    param($key)

    $quote = $key.KeyChar

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    # If text is selected, just quote it without any smarts
    if ($selectionStart -ne -1)
    {
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $quote + $line.SubString($selectionStart, $selectionLength) + $quote)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    # Don't be smart.
    # $ast = $null
    # $tokens = $null
    # $parseErrors = $null
    # [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$parseErrors, [ref]$null)

    # function FindToken
    # {
    #     param($tokens, $cursor)

    #     foreach ($token in $tokens)
    #     {
    #         if ($cursor -lt $token.Extent.StartOffset) { continue }
    #         if ($cursor -lt $token.Extent.EndOffset)
    #         {
    #             $result = $token
    #             $token = $token -as [StringExpandableToken]
    #             if ($token)
    #             {
    #                 $nested = FindToken $token.NestedTokens $cursor
    #                 if ($nested) { $result = $nested }
    #             }

    #             return $result
    #         }
    #     }
    #     return $null
    # }

    # $token = FindToken $tokens $cursor

    # # If we're on or inside a **quoted** string token (so not generic), we need to be smarter
    # if ($token -is [StringToken] -and $token.Kind -ne [TokenKind]::Generic)
    # {
    #     # If we're at the start of the string, assume we're inserting a new string
    #     if ($token.Extent.StartOffset -eq $cursor)
    #     {
    #         [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote ")
    #         [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    #         return
    #     }

    #     # If we're at the end of the string, move over the closing quote if present.
    #     if ($token.Extent.EndOffset -eq ($cursor + 1) -and $line[$cursor] -eq $quote)
    #     {
    #         [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    #         return
    #     }
    # }

    # if ($null -eq $token -or
    #     $token.Kind -eq [TokenKind]::RParen -or $token.Kind -eq [TokenKind]::RCurly -or $token.Kind -eq [TokenKind]::RBracket)
    # {
    #     if ($line[0..$cursor].Where{ $_ -eq $quote }.Count % 2 -eq 1)
    #     {
    #         # Odd number of quotes before the cursor, insert a single quote
    #         [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
    #     }
    #     else
    #     {
    #         # Insert matching quotes, move cursor to be in between the quotes
    #         [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
    #         [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
    #     }
    #     return
    # }

    # # If cursor is at the start of a token, enclose it in quotes.
    # if ($token.Extent.StartOffset -eq $cursor)
    # {
    #     if ($token.Kind -eq [TokenKind]::Generic -or $token.Kind -eq [TokenKind]::Identifier -or
    #         $token.Kind -eq [TokenKind]::Variable -or $token.TokenFlags.hasFlag([TokenFlags]::Keyword))
    #     {
    #         $end = $token.Extent.EndOffset
    #         $len = $end - $cursor
    #         [Microsoft.PowerShell.PSConsoleReadLine]::Replace($cursor, $len, $quote + $line.SubString($cursor, $len) + $quote)
    #         [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($end + 2)
    #         return
    #     }
    # }

    # We failed to be smart, so just insert a single quote
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($quote)
}

Set-PSReadLineKeyHandler -Key '(', '{', '[' `
    -BriefDescription InsertPairedBraces `
    -LongDescription "Insert matching braces" `
    -ScriptBlock {
    param($key)

    $closeChar = switch ($key.KeyChar)
    {
        <#case#> '(' { [char]')'; break }
        <#case#> '{' { [char]'}'; break }
        <#case#> '[' { [char]']'; break }
    }

    $selectionStart = $null
    $selectionLength = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$selectionStart, [ref]$selectionLength)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($selectionStart -ne -1)
    {
        # Text is selected, wrap it in brackets
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($selectionStart, $selectionLength, $key.KeyChar + $line.SubString($selectionStart, $selectionLength) + $closeChar)
        [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($selectionStart + $selectionLength + 2)
        return
    }

    # Don't be smart
    # # No text is selected, insert a pair
    # [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)$closeChar")
    # [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)

    # We failed to be smart, so just insert the char.
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($key.KeyChar)
}

# Set-PSReadLineKeyHandler -Key ')', ']', '}' `
#     -BriefDescription SmartCloseBraces `
#     -LongDescription "Insert closing brace or skip" `
#     -ScriptBlock {
#     param($key)

#     $line = $null
#     $cursor = $null
#     [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

#     if ($line[$cursor] -eq $key.KeyChar)
#     {
#         [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
#     }
#     else
#     {
#         [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$($key.KeyChar)")
#     }
# }

Set-PSReadLineKeyHandler -Key Backspace `
    -BriefDescription SmartBackspace `
    -LongDescription "Delete previous character or matching quotes/parens/braces" `
    -ScriptBlock {
    param($key, $arg)

    $line = $null
    $cursor = $null
    [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

    if ($cursor -gt 0)
    {
        $toMatch = $null
        if ($cursor -lt $line.Length)
        {
            switch ($line[$cursor])
            {
                <#case#> '"' { $toMatch = '"'; break }
                <#case#> "'" { $toMatch = "'"; break }
                <#case#> ')' { $toMatch = '('; break }
                <#case#> ']' { $toMatch = '['; break }
                <#case#> '}' { $toMatch = '{'; break }
            }
        }

        if ($toMatch -ne $null -and $line[$cursor - 1] -eq $toMatch)
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::Delete($cursor - 1, 2)
        }
        else
        {
            [Microsoft.PowerShell.PSConsoleReadLine]::BackwardDeleteChar($key, $arg)
        }
    }
}

#endregion Smart Insert/Delete

#endregion Key Handlers