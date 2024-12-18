#requires -version 7 -modules bootstrap.environment
[CmdletBinding(SupportsShouldProcess)]
param()

Set-EnvironmentVariable -Name 'RIPGREP_CONFIG_PATH' -Value (Join-Path ${HOME} '.ripgreprc') @PSBoundParameters