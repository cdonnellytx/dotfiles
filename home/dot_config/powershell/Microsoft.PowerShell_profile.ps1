# Force UTF-8 console.
if ($IsWindows)
{
    [void] (chcp 65001)
}
[Console]::OutputEncoding = $OutputEncoding