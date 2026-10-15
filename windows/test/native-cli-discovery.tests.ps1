$ErrorActionPreference='Stop'
$windows=Split-Path $PSScriptRoot -Parent
. (Join-Path $windows 'Native.ps1')
$node=$env:WIDGET_NATIVE_TEST_NODE
if(-not $node){$node=Find-WidgetNode $windows}
if(-not $node){throw 'Node.js 24 is required for the native CLI discovery fixture'}
$root=Join-Path ([IO.Path]::GetTempPath()) ('quota-cli-bridge-'+[guid]::NewGuid().ToString('N'))
function Write-FixturePE([string]$path){
 [void][IO.Directory]::CreateDirectory((Split-Path $path -Parent))
 $bytes=New-Object byte[] 256
 [BitConverter]::GetBytes([uint16]0x5a4d).CopyTo($bytes,0)
 [BitConverter]::GetBytes([int]64).CopyTo($bytes,60)
 [BitConverter]::GetBytes([uint32]0x4550).CopyTo($bytes,64)
 [BitConverter]::GetBytes([uint16]0x20b).CopyTo($bytes,88)
 [BitConverter]::GetBytes([uint16]3).CopyTo($bytes,156)
 [IO.File]::WriteAllBytes($path,$bytes)
}
try{
 foreach($name in @('FABRICATED module environment',"FABRICATED Team’s quota")){
  $fixture=Join-Path $root $name
  [void][IO.Directory]::CreateDirectory($fixture)
  Copy-Item -LiteralPath (Join-Path $windows 'cli.mjs') -Destination (Join-Path $fixture 'cli.mjs')
  $package=Join-Path $fixture 'package'
  $local=Join-Path $fixture 'Local'
  $roaming=Join-Path $fixture 'Roaming'
  $binary=Join-Path $package 'app/resources/codex.exe'
  $staged=Join-Path $local 'OpenAI/Codex/bin/FABRICATED_VERSION/codex.exe'
  Write-FixturePE $binary;Write-FixturePE $staged
  $shim=Join-Path $roaming 'npm/codex.cmd'
  [void][IO.Directory]::CreateDirectory((Split-Path $shim -Parent))
  [IO.File]::WriteAllText($shim,'FABRICATED incomplete npm install - never executed')
  # Only the installed-package and PATH lookup boundaries are substituted.
  # Native hashing, Store discovery and the production Node/PowerShell bridge run.
  $native=[IO.File]::ReadAllText((Join-Path $windows 'Native.ps1'))+@'

function Get-AppxPackage {
 [CmdletBinding()]param([string]$Name)
 [pscustomobject]@{InstallLocation=$env:WIDGET_FAKE_PACKAGE}
}
function Get-Command {
 [CmdletBinding()]param([string]$Name)
 if($Name -eq 'Get-AppxPackage'){return [pscustomobject]@{Source='FABRICATED package lookup'}}
 if($Name -eq 'codex.exe'){return $null}
 if($Name -eq 'codex.cmd'){return [pscustomobject]@{Source=(Join-Path $env:APPDATA 'npm/codex.cmd')}}
 Microsoft.PowerShell.Core\Get-Command $Name -ErrorAction SilentlyContinue
}
'@
  [IO.File]::WriteAllText((Join-Path $fixture 'Native.ps1'),$native,[Text.UTF8Encoding]::new($true))
  $shadow=Join-Path $fixture 'Core-only-modules/Microsoft.PowerShell.Utility/7.0.0'
  [void][IO.Directory]::CreateDirectory($shadow)
  [IO.File]::WriteAllText((Join-Path $shadow 'Microsoft.PowerShell.Utility.psd1'),"@{ModuleVersion='7.0.0';PowerShellVersion='7.0';CompatiblePSEditions=@('Core');RootModule='fake.psm1';CmdletsToExport=@('Get-FileHash')}")
  [IO.File]::WriteAllText((Join-Path $shadow 'fake.psm1'),'# FABRICATED incompatible parent module - never imported')
  $worker=@'
import {resolveCodex} from './cli.mjs';
import {join} from 'node:path';
import {fileURLToPath} from 'node:url';
import assert from 'node:assert/strict';
const root=fileURLToPath(new URL('./',import.meta.url));
process.env.LOCALAPPDATA=join(root,'Local');process.env.APPDATA=join(root,'Roaming');
process.env.WIDGET_FAKE_PACKAGE=join(root,'package');
process.env.PATH=join(root,'removed-version');process.env.CODEX_CLI_PATH=join(root,'removed-version','codex.exe');
process.env.PSModulePath=join(root,'Core-only-modules');
const expected=join(root,'Local','OpenAI','Codex','bin','FABRICATED_VERSION','codex.exe');
assert.deepEqual(resolveCodex(),{command:expected,args:['app-server']});
assert.equal(process.env.CODEX_CLI_PATH,expected);
assert.deepEqual(resolveCodex(),{command:expected,args:['app-server']});
// The selected fabricated executable is validated but never spawned.
'@
  $workerPath=Join-Path $fixture 'worker.mjs'
  [IO.File]::WriteAllText($workerPath,$worker,[Text.UTF8Encoding]::new($false))
  & $node $workerPath
  if($LASTEXITCODE){throw ('Native rediscovery fixture failed: '+$name)}
  Write-Output ('PASS native CLI rediscovery preserves Store validation and caches the result: '+$name)
 }
}finally{
 $resolved=[IO.Path]::GetFullPath($root);$temp=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
 if($resolved.StartsWith($temp,[StringComparison]::OrdinalIgnoreCase) -and [IO.Path]::GetFileName($resolved).StartsWith('quota-cli-bridge-')){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
