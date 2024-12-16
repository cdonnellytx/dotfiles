[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
param()

# @see https://docs.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete
# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName 'dotnet' -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition, $commandAst, $fakeBoundParameters)

    $debug = $DebugArgumentCompleter['dotnet']

    if ($debug)
    {
        Write-Warning "dotnet completion:`n----------------------`n$([PSCustomObject] @{ CommandName = $commandName; wordToComplete = $wordToComplete; cursorPosition = $cursorPosition; commandAst = $commandAst; fakeBoundParameters = $fakeBoundParameters } | Out-String) "
    }

    # MSCRAP: Many of the dotnet completions DO NOT return filenames even where they are valid, only options.
    # Additionally, there's no good way to say "gimme files too" in PowerShell.
    $words = $wordToComplete.CommandElements | ForEach-Object { $_.ToString() }
    if ($words -ccontains '--')
    {
        switch -wildcard ($wordToComplete.Extent.Text)
        {
            '* --' {
                if ($cursorPosition -gt $wordToComplete.Extent.EndOffset) {
                    if ($debug) { Write-Warning "SPECIAL: force filenames ($cursorPosition -gt $($wordToComplete.GetType()) $($wordToComplete.Length))" }
                    return
                }
            }
            '* -- *' {
                $dashDashEnd = $_.IndexOf(' -- ') + 3 # skip space,dash,dash
                if ($cursorPosition -gt $dashDashEnd) {
                    if ($debug) { Write-Warning "SPECIAL: force filenames ($cursorPosition -gt $dashDashend; w2c=$($wordToComplete.Extent.EndOffset))" }
                    return
                }
            }
        }
    }

    # Default: complete via dotnet completion
    if ($debug)
    {
        Write-Warning "Invoking: dotnet complete --position $cursorPosition `"${wordToComplete}`" # CommandName = $($commandName|Out-String); wordToComplete=$($wordToComplete|Out-String); cursorPosition=$($cursorPosition|Out-String); commandAst=$($commandAst|Out-String); fakeBoundParameters=$($fakeBoundParameters | Out-String) "
    }

    dotnet complete --position $cursorPosition "${wordToComplete}" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
 }