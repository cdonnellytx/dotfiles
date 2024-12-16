#requires -version 7 -modules bootstrap.environment, bootstrap.ux
[CmdletBinding()]
param()

Set-StrictMode -Version Latest

Enter-Operation "Set POSH_THEME"
if ($PSCmdlet.ShouldProcess("Set POSH_THEME"))
{
    Set-EnvironmentVariable -Name 'POSH_THEME' -Value "${HOME}/.oh-my-posh/themes/cdonnelly.omp.json" -Target User -ErrorVariable err
}

Exit-Operation -Error:$Err