$ErrorActionPreference = 'Stop'
$repository = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$builder = Join-Path $repository 'installer/windows/Build.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('quota-build-test-' + [guid]::NewGuid())
function Expect-PreflightFailure([string]$output, [string]$version, [string]$expected) {
    try { & $builder -NodeRoot (Join-Path $scratch 'missing-node') -OutputDir $output -Version $version; throw 'Builder accepted invalid input.' }
    catch { if (-not $_.Exception.Message.Contains($expected)) { throw "Wrong build preflight result: $($_.Exception.Message)" } }
}
Expect-PreflightFailure $scratch '0.1.0' 'NodeRoot must contain'
Expect-PreflightFailure (Join-Path $repository 'test-output') '0.1.0' 'Build output must be outside'
Expect-PreflightFailure $scratch 'invalid version' 'Version must be'
if (Test-Path -LiteralPath $scratch) { throw 'Failed preflight wrote an output directory.' }
Write-Output 'PASS build preflight rejects missing runtime, repository output and invalid version without writing artifacts'
