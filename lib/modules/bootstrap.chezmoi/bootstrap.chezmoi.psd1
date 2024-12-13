@{
    RootModule = 'bootstrap.chezmoi.psm1'
    ModuleVersion = '0.1.0'
    GUID = '5392ac22-7470-46c0-91ca-5690b6257451'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Invoke-Chezmoi',
        'Get-ChezmoiData',
        'Get-ChezmoiWorkingTree'
    )
    CmdletsToExport = @()
    VariablesToExport =  @()
    AliasesToExport = @()
}