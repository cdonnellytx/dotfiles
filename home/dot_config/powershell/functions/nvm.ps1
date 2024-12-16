#Requires -Version 5.1

Set-StrictMode -Version Latest

# Force Set-NodeInstallLocation to confirm.
# Requires nvm > 2.5.1.
$PSDefaultParameterValues['Set-NodeInstallLocation:Confirm'] = $true
