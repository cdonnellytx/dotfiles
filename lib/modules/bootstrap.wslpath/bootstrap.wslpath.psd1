@{
    RootModule = 'bootstrap.wslpath.psm1'
    ModuleVersion = '0.9.0'
    GUID = '96f91503-01b1-470d-ac16-174b8990ec5a'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Get-WslPath'
    )
    CmdletsToExport = @()
    AliasesToExport = @('wslpath')
    VariablesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )
}