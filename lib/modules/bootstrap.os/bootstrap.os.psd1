@{
    RootModule = 'bootstrap.os.psm1'
    ModuleVersion = '0.3.0'
    GUID = '2efd06db-67be-42c7-8088-08f35786a064'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Test-IsAdministrator',
        'Assert-IsAdminstrator'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )
}
