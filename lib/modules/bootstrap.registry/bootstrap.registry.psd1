@{
    RootModule = 'bootstrap.registry.psm1'
    ModuleVersion = '0.1.0'
    GUID = '3ee09ec2-a7c8-4858-8726-081260440eff'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Confirm-RegistryPath',
        'Confirm-RegistryEntry'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
        'bootstrap.ux'
    )
}