@{
    RootModule = 'bootstrap.iis.psm1'
    ModuleVersion = '0.1.0'
    GUID = '4579dd08-13d3-436c-ab02-a4e8a2cee2b7'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Helpers for IIS'

    FunctionsToExport = '*'
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop')
    RequiredModules = @(
        'bootstrap.core'
    )
}
