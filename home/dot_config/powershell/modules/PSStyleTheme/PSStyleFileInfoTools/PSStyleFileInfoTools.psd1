@{
    RootModule = 'PSStyleFileInfoTools.psm1'
    ModuleVersion = '0.0.2'
    GUID = '4258f3f9-ebdd-1e1f-3305-a9b2cf61d831'

    Author = '@jdhitsolutions'
    Copyright = '(c) @jdhitsolutions'
    Description = 'A set of functions for exporting and importing FileInfo settings from $PSStyle in PowerShell 7.2.'

    CompatiblePSEditions = @('Core')
    PowerShellVersion = '7.2'
    ProcessorArchitecture = 'None'

    RequiredModules = @()
    RequiredAssemblies = @()
    ScriptsToProcess = @()
    NestedModules = @()

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @(
        'Export-PSStyleFileInfo',
        'Import-PSStyleFileInfo'
    )
    VariablesToExport = @()
    FileList = 'PSStyleFileInfoTools.psm1'
}

