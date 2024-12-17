@{
    RootModule = 'bootstrap.powershell.psm1'
    ModuleVersion = '0.1.0'
    GUID = '33dd3070-d3c7-4781-804e-5b5ff49d9eac'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Install-ViaPSResourceGet'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    RequiredModules = @(
        'bootstrap.logging',
        'bootstrap.os',
        'bootstrap.parser',
        'Microsoft.PowerShell.PSResourceGet'
    )
}

