@{
    RootModule = 'mklink.psm1'
    ModuleVersion = '0.0.3'
    GUID = '64722aa6-aa74-4847-9529-9b6f8230802a'

    # Author of this module
    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'mklink function similar to builtin "mkdir" function'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @(
        'mklink'
    )
    VariablesToExport = @()

    FileList = @('mklink.psm1')
}
