@{
    RootModule = 'bootstrap.utility.psm1'
    ModuleVersion = '0.1.0'
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

    PowerShellVersion = '7.0'
    RequiredModules = @(
        'Microsoft.PowerShell.Utility'
    )
}

