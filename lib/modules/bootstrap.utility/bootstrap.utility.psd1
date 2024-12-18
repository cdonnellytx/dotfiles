@{
    RootModule = 'bootstrap.utility.psm1'
    ModuleVersion = '0.2.0'
    GUID = 'e7b537db-475f-4d78-a1dd-a10dee9a4aab'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Measure-TimeSpan',
        'Resolve-Condition'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
        'Microsoft.PowerShell.Utility'
    )
}
