#requires -version 7.0

Set-StrictMode -Version Latest

<#
.SYNOPSIS
Tests whether the current user is running as administrator.
#>
function Test-IsAdministrator
{
    [OutputType([bool])]
    param()

    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}