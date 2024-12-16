@{
    RootModule = 'PSStyleTheme.psm1'
    ModuleVersion = '0.4.3'
    GUID = '23ddb387-fcb3-436e-acd3-ac60308b2a8e'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Loads PSStyle themes'

    CompatiblePSEditions = @('Core')
    PowerShellVersion = '7.2'
    ProcessorArchitecture = 'None'

    FormatsToProcess = @('PSStyleTheme.format.ps1xml')
    TypesToProcess = @('PSStyleTheme.types.ps1xml')

    RequiredModules = @(
        'PSReadline',
        'posh-stopwatch'
    )

    RequiredAssemblies = @()
    ScriptsToProcess = @()
    NestedModules = @(
        'PSStyleFileInfoTools'
    )

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @(
        'Get-PSStyleTheme',
        'Show-PSStyleTheme',
        'Set-PSStyleTheme'
    )
    VariablesToExport = @()

    FileList = 'PSStyleTheme.psm1'
}

