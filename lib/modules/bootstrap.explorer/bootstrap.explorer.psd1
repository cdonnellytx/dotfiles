@{
    RootModule = 'bootstrap.explorer.psm1'
    ModuleVersion = '0.2.0'
    GUID = '424bc105-b193-42a1-ba31-2564ce0fde16'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Get-Shortcut',
        'New-Shortcut',
        'Confirm-PathIsShortcut'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )
}
