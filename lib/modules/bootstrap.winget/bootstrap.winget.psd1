@{
    RootModule = 'bootstrap.winget.psm1'
    ModuleVersion = '0.8.0'
    GUID = '33dd3070-d3c7-4781-804e-5b5ff49d9eac'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Find-ViaWinGet',
        'Install-ViaWinGet',
        'Lock-WinGet'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}

