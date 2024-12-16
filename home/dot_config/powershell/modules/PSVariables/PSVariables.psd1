@{
    RootModule = 'PSVariables.psm1'
    ModuleVersion = '3.0.0'
    GUID = '339677a6-1464-436a-8edd-e9256f77c156'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'PowerShell Variable Support'

    PowerShellVersion = '4.0'
    CLRVersion = '4.0'
    DotNetFrameworkVersion = '4.0'
    ProcessorArchitecture = 'None'

    AliasesToExport = @()
    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @(
        # For PowerShell < 5.1
        'PSEdition',

        # For PowerShell 5.1
        'IsCoreCLR', 'IsWindows', 'IsLinux', 'IsMacOS',

        # My extras
        'IsAdministrator'
    )

    FileList = 'PSVariables.psm1'
}

