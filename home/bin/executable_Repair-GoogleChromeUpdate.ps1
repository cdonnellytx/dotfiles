Using Namespace Microsoft.Win32

[CmdletBinding(SupportsShouldProcess)]
param
(
)

if (!$IsAdministrator) { throw "Must run as administrator" }

[RegistryKey] $item = Get-Item HKLM:\SOFTWARE\Policies\Google\Update -ErrorAction Stop

$item.GetValueNames() | Where-Object {
    $_ -like 'Update*' -and
        $Item.GetValueKind($_) -eq [RegistryValueKind]::DWord -and
        $Item.GetValue($_) -eq 0
} | ForEach-Object {
    Set-ItemProperty -LiteralPath $item.PSPath -Name $_ -Value 1 -ErrorAction Stop
}
