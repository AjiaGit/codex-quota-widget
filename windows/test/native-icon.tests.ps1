$ErrorActionPreference = 'Stop'
$icon = Join-Path (Split-Path $PSScriptRoot -Parent) 'CodexQuota.ico'
$bytes = [IO.File]::ReadAllBytes($icon)
if ([BitConverter]::ToUInt16($bytes,0) -ne 0 -or [BitConverter]::ToUInt16($bytes,2) -ne 1) { throw 'Quota icon must have an ICO header.' }
$count = [BitConverter]::ToUInt16($bytes,4)
if ($count -lt 1) { throw 'Quota icon must contain a bitmap.' }
for ($i = 0; $i -lt $count; $i++) {
    $entry = 6 + 16 * $i
    if ($bytes[$entry+3] -ne 0) { throw 'Quota icon entry reserved byte is not zero.' }
    if ([BitConverter]::ToUInt16($bytes,$entry+4) -ne 1) { throw 'Quota icon requires one bitmap plane.' }
    if ([BitConverter]::ToUInt16($bytes,$entry+6) -ne 32) { throw 'Quota icon requires a 32-bit bitmap.' }
    $size = [BitConverter]::ToUInt32($bytes,$entry+8); $offset = [BitConverter]::ToUInt32($bytes,$entry+12)
    if ($size -eq 0 -or $offset -lt 6 + 16*$count -or $offset + $size -gt $bytes.Length) { throw 'Quota icon bitmap offset is invalid.' }
}
if ($env:OS -eq 'Windows_NT') {
    Add-Type -AssemblyName System.Drawing
    $loaded = [Drawing.Icon]::new($icon)
    try { if ($loaded.Width -lt 16) { throw 'Quota icon is too small.' } } finally { $loaded.Dispose() }
}
Write-Output 'PASS quota icon is a valid original quota ring asset'
