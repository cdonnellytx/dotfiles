@{
    RootModule = 'bootstrap.chezmoi.psm1'
    ModuleVersion = '0.2.0'
    GUID = '5392ac22-7470-46c0-91ca-5690b6257451'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Invoke-Chezmoi',
        'Invoke-ChezmoiTemplate',
        'Get-ChezmoiData',
        'Get-ChezmoiHomeDir',
        'Get-ChezmoiSourceDir',
        'Get-ChezmoiWorkingTree'
    )
    CmdletsToExport = @()
    VariablesToExport =  @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )
}
