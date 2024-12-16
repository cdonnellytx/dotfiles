@{
    RootModule = 'posh-gh.psm1'
    ModuleVersion = '0.0.4'
    GUID = 'a9db88d9-4719-4140-88d9-da4c70221272'

    # Author of this module
    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'gh argument completion module'

    PowerShellVersion = '5.1'
    ProcessorArchitecture = 'None'

    RequiredModules = @(
        'PSReadLine'
    )

    FunctionsToExport = @()
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()

    FileList = @('posh-gh.psm1')
}

