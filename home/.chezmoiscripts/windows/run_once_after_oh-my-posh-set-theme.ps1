[CmdletBinding()]
param()

if ($PSCmdlet.ShouldProcess("Set POSH_THEME"))
{
    [System.Environment]::SetEnvironmentVariable('POSH_THEME', "${HOME}/.oh-my-posh/themes/cdonnelly.omp.json", [System.EnvironmentVariableTarget]::User)
}