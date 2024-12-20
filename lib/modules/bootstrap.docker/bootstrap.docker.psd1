@{
    RootModule = 'bootstrap.docker.psm1'
    ModuleVersion = '0.1.0'
    GUID = '44b1aefa-8bc5-4785-9335-d21d99e28b32'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    FunctionsToExport = @(
        'Test-DockerContainer'
    )
    CmdletsToExport = @()
    VariablesToExport =  @()
    AliasesToExport = @()

    PowerShellVersion = '7.4'
    RequiredModules = @(
        'bootstrap.core'
    )
}