$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../Native.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('quota-codex-'+[guid]::NewGuid().ToString('N'))
$oldCli=$env:CODEX_CLI_PATH; $oldLocal=$env:LOCALAPPDATA; $oldApp=$env:APPDATA
$script:pathCandidate=$null
function Get-Command {
 [CmdletBinding()]param([string]$Name)
 if($Name -eq 'Get-AppxPackage'){return [pscustomobject]@{Source='FABRICATED package lookup'}}
 if($Name -eq 'codex.exe' -and $script:pathCandidate){return [pscustomobject]@{Source=$script:pathCandidate}}
 if($Name -in @('codex.exe','codex.cmd')){return $null}
 Microsoft.PowerShell.Core\Get-Command $Name -ErrorAction SilentlyContinue
}
function Get-AppxPackage {
 [CmdletBinding()]param([string]$Name)
 [pscustomobject]@{InstallLocation=(Join-Path $root 'package')}
}
function Write-FixturePE([string]$path,[uint16]$subsystem) {
 [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
 $bytes=New-Object byte[] 256
 [BitConverter]::GetBytes([uint16]0x5a4d).CopyTo($bytes,0)
 [BitConverter]::GetBytes([int]64).CopyTo($bytes,60)
 [BitConverter]::GetBytes([uint32]0x4550).CopyTo($bytes,64)
 [BitConverter]::GetBytes([uint16]0x20b).CopyTo($bytes,88)
 [BitConverter]::GetBytes($subsystem).CopyTo($bytes,156)
 [IO.File]::WriteAllBytes($path,$bytes)
}
try {
 [void][IO.Directory]::CreateDirectory($root)
 $env:LOCALAPPDATA=Join-Path $root 'Local'; $env:APPDATA=Join-Path $root 'Roaming'; $env:CODEX_CLI_PATH=$null
 $gui=Join-Path $root 'package/app/Codex.exe'; $cli=Join-Path $root 'package/app/resources/codex.exe'
 Write-FixturePE $gui 2; Write-FixturePE $cli 3
 if((Find-WidgetCodex) -ne $cli){throw 'Store discovery selected the GUI executable instead of the bundled CLI'}
 Write-Output 'PASS Store discovery selects CLI, not the GUI host (FABRICATED PE DATA)'
 $script:pathCandidate=$gui
 if((Find-WidgetCodex) -ne $cli){throw 'GUI PATH entry blocked Store CLI discovery'}
 Write-Output 'PASS GUI PATH entries are skipped'
 $env:CODEX_CLI_PATH=$gui
 if((Find-WidgetCodex) -ne $cli){throw 'GUI override blocked Store CLI discovery'}
 Write-Output 'PASS GUI overrides are skipped'
 $explicit=Join-Path $root 'explicit/codex.exe'; Write-FixturePE $explicit 3
 $env:CODEX_CLI_PATH=$explicit
 if((Find-WidgetCodex) -ne $explicit){throw 'Console override not honored'}
 Write-Output 'PASS console override remains preferred'
 $shim=Join-Path $root 'explicit/codex.CMD'; [IO.File]::WriteAllText($shim,'FABRICATED TEST DATA - never executed')
 $env:CODEX_CLI_PATH=$shim
 if((Find-WidgetCodex) -ne $shim){throw 'npm shim override not preserved'}
 Write-Output 'PASS npm shim override remains discoverable'
 $invalid=Join-Path $root 'invalid.exe'; [IO.File]::WriteAllBytes($invalid,(New-Object byte[] 3))
 $env:CODEX_CLI_PATH=$invalid
 if((Find-WidgetCodex) -ne $cli -or (Test-WidgetCodexCandidate $invalid)){throw 'Malformed PE was accepted'}
 Write-Output 'PASS malformed and vanished overrides fall back safely'
 $invalidBytes=New-Object byte[] 256; [BitConverter]::GetBytes([uint16]0x5a4d).CopyTo($invalidBytes,0); [BitConverter]::GetBytes([int]2147483647).CopyTo($invalidBytes,60)
 [IO.File]::WriteAllBytes($invalid,$invalidBytes)
 if(Test-WidgetCodexCandidate $invalid){throw 'Out-of-range PE offset was accepted'}
 Write-Output 'PASS out-of-range PE metadata is rejected without launching'
 $env:CODEX_CLI_PATH=Join-Path $root 'missing.exe'
 if((Find-WidgetCodex) -ne $cli){throw 'Vanished override blocked Store discovery'}
 $script:pathCandidate=$null
 $staged=Join-Path $env:LOCALAPPDATA 'OpenAI/Codex/bin/FABRICATED_VERSION/codex.exe'
 [void][IO.Directory]::CreateDirectory((Split-Path $staged -Parent)); Copy-Item -LiteralPath $cli -Destination $staged
 if((Find-WidgetCodex) -ne $staged){throw 'Matching extracted Store CLI was not preferred over protected package binary'}
 Write-Output 'PASS Store discovery prefers a byte-identical extracted CLI'
 $bytes=[IO.File]::ReadAllBytes($staged); $bytes[252]=1; [IO.File]::WriteAllBytes($staged,$bytes)
 if((Find-WidgetCodex) -ne $cli){throw 'Different extracted CLI was trusted as the installed package CLI'}
 Write-Output 'PASS unrelated extracted binaries cannot substitute for the installed CLI'
 Remove-Item -LiteralPath $staged -Force
 Remove-Item -LiteralPath $cli -Force
 if($null -ne (Find-WidgetCodex)){throw 'GUI-only package was accepted as a CLI'}
 Write-Output 'PASS GUI-only packages do not masquerade as a CLI'
} finally {
 $env:CODEX_CLI_PATH=$oldCli; $env:LOCALAPPDATA=$oldLocal; $env:APPDATA=$oldApp
 $resolved=[IO.Path]::GetFullPath($root); $temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if($resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('quota-codex-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
