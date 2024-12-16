@{
    RootModule = 'Pansies.Colors.psm1'
    ModuleVersion = '0.2.0'
    GUID = 'ddcca5f0-07dd-472d-abc7-fbeca85b5c20'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Pansies color extensions'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @('Pansies')

    CmdletsToExport = @()
    FunctionsToExport = @(
        'Get-RgbColor',
        'Get-BgrColor',
        'Get-HsbColor',
        'ConvertTo-AnsiSequence',
        'Get-ArgbColor',
        'Get-RgbaColor'
    )
    AliasesToExport = @('Get-HsvColor')
    VariablesToExport = @()

    TypesToProcess = 'Pansies.Colors.types.ps1xml'
    FormatsToProcess = 'Pansies.Colors.format.ps1xml'


    FileList = 'Pansies.Colors.psm1', 'Pansies.Colors.format.ps1xml', 'Pansies.Colors.types.ps1xml'
}

