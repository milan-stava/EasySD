$ErrorActionPreference = 'Stop'

$backendFile = '_switcher_backend.bin'
$uiFile      = '_switcher_ui.bin'
$outFile     = 'switcher_1_1_full.bin'

$baseAddress = 0x8000
$uiAddress   = 0x8800
$limit       = 0x9000
$uiOffset    = $uiAddress - $baseAddress
$maxSize     = $limit - $baseAddress

$backend = [System.IO.File]::ReadAllBytes($backendFile)
$ui      = [System.IO.File]::ReadAllBytes($uiFile)

if ($backend.Length -gt $uiOffset) {
    throw ('Backend is too large: {0} bytes; it overlaps #8800 by {1} bytes.' -f $backend.Length, ($backend.Length - $uiOffset))
}

$totalSize = $uiOffset + $ui.Length
if ($totalSize -gt $maxSize) {
    throw ('UI helper exceeds #9000. Combined image would be {0} bytes.' -f $totalSize)
}

$out = New-Object byte[] $totalSize
[Array]::Copy($backend, 0, $out, 0, $backend.Length)
[Array]::Copy($ui, 0, $out, $uiOffset, $ui.Length)
[System.IO.File]::WriteAllBytes($outFile, $out)

$sha = (Get-FileHash -Algorithm SHA256 $outFile).Hash.ToLowerInvariant()
$backendEnd = $baseAddress + $backend.Length - 1
$uiEnd = $uiAddress + $ui.Length - 1
$gap = $uiOffset - $backend.Length

Write-Host ('Backend : {0} bytes  #{1:X4}-#{2:X4}' -f $backend.Length, $baseAddress, $backendEnd)
Write-Host ('Gap     : {0} bytes' -f $gap)
Write-Host ('UI      : {0} bytes  #{1:X4}-#{2:X4}' -f $ui.Length, $uiAddress, $uiEnd)
Write-Host ('Output  : {0} bytes  #{1:X4}-#{2:X4}' -f $out.Length, $baseAddress, ($baseAddress + $out.Length - 1))
Write-Host ('SHA256  : {0}' -f $sha)

if ($out.Length -eq 2406 -and $sha -eq '9de6752a04e46786fec1c5a5296ece0a75d43e874a4b03626f18c9dd0c7829b0') {
    Write-Host 'MATCH   : reference Switcher binary is byte-for-byte identical.'
} else {
    Write-Host 'NOTE    : output differs from the current reference binary.'
}
