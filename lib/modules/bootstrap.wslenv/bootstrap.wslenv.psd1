
@{
    RootModule = 'bootstrap.wslenv.psm1'
    ModuleVersion = '0.8.0.2'
    GUID = '6b65f1df-c17b-49b9-98ba-7741724ae84b'
    Author = 'Chris R. Donnelly'
    CompanyName = ''
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'
    Description = 'PowerShell WSLENV wrapper'
    RequiredModules = @('bootstrap.environment')
    FunctionsToExport = @(
        'Get-WslEnvironment', 'Set-WSLEnvironment', 'Add-WSLEnvironment',
        'Remove-WSLEnvironment'
    )
    CmdletsToExport = @()
    AliasesToExport = @()
    VariablesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = 'wsl','core','pscore','windows','subsystem','linux','environment','wslenv'

        }
    }
}

