#requires -version 7 -modules bootstrap.environment, bootstrap.ux
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest

Set-EnvironmentVariable -Name 'POSH_THEME' -Value "${HOME}/.oh-my-posh/themes/cdonnelly.omp.json" -Target User
