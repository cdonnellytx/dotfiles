#requires -version 7 -modules bootstrap.environment
[CmdletBinding(SupportsShouldProcess)]
param()

Set-EnvironmentVariable -Name 'RIPGREP_CONFIG_PATH' -Target User -Value (Join-Path ${HOME} '.ripgreprc') @PSBoundParameters
