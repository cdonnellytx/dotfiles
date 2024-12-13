@{
    RootModule = 'bootstrap.wslpath.psm1'
    ModuleVersion = '0.8.0.3'
    GUID = '96f91503-01b1-470d-ac16-174b8990ec5a'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'PowerShell WSLPath implementation'
    FunctionsToExport = @(
        'Get-WslPath'
    )
    CmdletsToExport = @()
    AliasesToExport = @('wslpath')
    VariablesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = 'wsl','core','pscore','windows','subsystem','linux','wslpath'
        }

    }
}