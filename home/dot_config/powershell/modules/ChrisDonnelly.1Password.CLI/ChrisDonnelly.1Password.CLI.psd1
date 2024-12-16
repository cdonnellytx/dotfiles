@{
    RootModule = 'ChrisDonnelly.1Password.CLI.psm1'
    ModuleVersion = '0.2.0'
    GUID = 'ad11cc1f-2932-479a-9c5f-4661855c3cf4'

    # Author of this module
    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Wrapper for 1Password CLI (`op`)'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    TypesToProcess = @()
    FormatsToProcess = @('ChrisDonnelly.1Password.CLI.format.ps1xml')

    RequiredModules = @()

    FunctionsToExport = @(
        'Invoke-1Password'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @('iop')

    FileList = @('ChrisDonnelly.1Password.CLI.psm1')
}

