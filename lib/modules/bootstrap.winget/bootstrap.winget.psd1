@{
    RootModule = 'bootstrap.winget.psm1'
    ModuleVersion = '0.10.0'
    GUID = '33dd3070-d3c7-4781-804e-5b5ff49d9eac'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'ConvertTo-WinGetItem'
        'Find-ViaWinGet',
        'Install-ViaWinGet',
        'Limit-WinGetPackage'
        'Test-WinGetItem'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
        'bootstrap.utility'
        'Microsoft.WinGet.Client'
    )
}
