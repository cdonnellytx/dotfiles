@{
    RootModule = 'XMLConverter.psm1'
    ModuleVersion = '0.0.5'
    GUID = '269c8667-fc1a-49b6-9e83-08d7ae970436'

    Author = 'Chris R. Donnelly', 'Phil Factor'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'Sane versions of XML conversion that behave like JSON/YAML converters.'

    PowerShellVersion = '7.0'
    ProcessorArchitecture = 'None'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()

    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'ConvertFrom-Xml'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    PrivateData = @{
        PSData = @{
            Prerelease = ''
        }
    }
}

