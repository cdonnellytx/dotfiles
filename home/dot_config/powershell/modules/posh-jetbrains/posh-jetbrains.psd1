@{

    RootModule = 'posh-jetbrains.psm1'
    ModuleVersion = '0.0.1'
    GUID = '724478d5-d481-4a0f-bc3b-15f73230ab2b'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'JetBrains tools'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @()
    RequiredAssemblies = @()

    ScriptsToProcess = @()
    TypesToProcess = @()
    FormatsToProcess = @()
    NestedModules = @()

    FunctionsToExport = @('Get-JetBrainsApp', 'Start-JetBrainsApp')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = '*' # will be dynamic
}

