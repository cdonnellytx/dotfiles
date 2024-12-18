@{
    RootModule = 'bootstrap.parser.psm1'
    ModuleVersion = '0.1.0'
    GUID = 'bc0d85e0-b575-4daf-9951-9c2eb70e3719'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'ConvertFrom-FixedWidth'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
        'bootstrap.environment'
    )
}
