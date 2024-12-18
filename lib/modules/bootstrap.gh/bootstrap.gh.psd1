@{
    RootModule = 'bootstrap.gh.psm1'
    ModuleVersion = '0.2.0'
    GUID = '719c375f-6a5c-4528-b066-e4943394d6ac'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Get-GitHubRelease'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
        'bootstrap.logging'
    )
}
