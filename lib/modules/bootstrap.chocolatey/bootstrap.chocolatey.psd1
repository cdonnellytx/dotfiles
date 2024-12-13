@{
    RootModule = 'bootstrap.chocolatey.psm1'
    ModuleVersion = '0.1.0'
    GUID = '6c85c829-21f8-44bc-9fdc-702f103afe1c'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Test-Chocolatey',
        'Get-Chocolatey',
        'Install-ViaChocolatey',
        'Find-ViaChocolatey',
        'Show-ViaChocolatey'
    )
    CmdletsToExport = @()
    VariablesToExport =  @()
    AliasesToExport = @()
}