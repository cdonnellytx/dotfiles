if (!(Get-Module -Name PSVariables))
{
    # MSCRAP: VS2017 executes profile.ps1 before NuGet_profile.ps1, but 2019 does not.  Thanks guys.
    & (Join-Path $PSScriptRoot profile.ps1)
}

# cdonnelly 2018-05-09: NuGet console doesn't understand ANSI escapes.
if (Test-Path Variable:Global:GitPromptSettings)
{
    $GitPromptSettings.AnsiConsole = $false
}

