@{
    RootModule = 'tfenv.psm1'
    ModuleVersion = '0.6.0'
    GUID = 'a8f08b27-7df5-470c-9876-fb9ce65221c0'

    Description = 'tfenv: Terraform Version Manager for PowerShell'
    Author = 'Chris R. Donnelly'
    Copyright = '(c) Chris R. Donnelly. All rights reserved.'

    PowerShellVersion = '5.1'

    RequiredModules = @(
        'PSVariables'
    )

    FunctionsToExport = @(
        'Get-TerraformVersion',
        'Use-TerraformVersion',
        'Install-TerraformVersion',
        'Uninstall-TerraformVersion',
        'Find-TerraformVersion',
        'Lock-TerraformVersion',
        'Get-CurrentTerraformVersion',

        'Invoke-TFEnv',

        'Invoke-Terraform'
    )

    CmdletsToExport = @()

    VariablesToExport = @()

    AliasesToExport = @(
        'terraform',
        'tfenv',

        'Pin-TerraformVersion',
        'Switch-TerraformVersion'
    )
}

