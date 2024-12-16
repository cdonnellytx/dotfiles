@{
    RootModule = 'posh-plist.psm1'
    ModuleVersion = '0.2.0'
    GUID = '9389cfcd-b9c9-4a03-a6b6-3c779e8e9165'

    Author = 'Chris R. Donnelly'
    Copyright = '(c) 2022 Chris R. Donnelly. All rights reserved.'
    Description = 'Plist support'

    PowerShellVersion = '7.0'
    ProcessorArchitecture = 'None'

    AliasesToExport = @()
    CmdletsToExport = @()
    FunctionsToExport = @('ConvertFrom-Plist', 'ConvertTo-Plist')
    VariablesToExport = @()

    FileList = 'posh-plist.psm1'

    PrivateData = @{
        PSData = @{
            Prerelease = 'beta2'
        }
    }
}

