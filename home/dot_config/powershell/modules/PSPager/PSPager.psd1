@{
    RootModule = 'PSPager.psm1'
    ModuleVersion = '2.0.2'
    GUID = '0aadc5dd-df2e-494a-91f2-ad0fa7455f54'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) 2016-2021 Chris R. Donnelly. All rights reserved.'
    Description = '$Env:PAGER command support for PowerShell Desktop'

    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop') # Core doesn't need this -- its help honors Pager
    ProcessorArchitecture = 'None'
    RequiredModules = @('PSVariables')

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @('help')
    VariablesToExport = @()

    FileList = 'PSPager.psm1'
}

