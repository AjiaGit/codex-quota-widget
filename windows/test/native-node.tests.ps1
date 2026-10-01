$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'Native.ps1')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('quota-node-test-' + [guid]::NewGuid())
$oldPath = $env:PATH
try {
    $runtime = Join-Path $scratch 'runtime'
    [void][IO.Directory]::CreateDirectory($runtime)
    $candidate = Join-Path $runtime 'node.exe'
    if ($env:OS -eq 'Windows_NT') {
        $source = Join-Path $scratch 'Probe.cs'
        [IO.File]::WriteAllText($source, 'using System; using System.Threading; class Probe { static int Main() { Console.WriteLine("v24.19.0"); Thread.Sleep(1000); return Environment.GetEnvironmentVariable("QUOTA_NODE_PROBE_FAIL") == "1" ? 7 : 0; } }')
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
        & $compiler /nologo /target:exe "/out:$candidate" $source
        if ($LASTEXITCODE -ne 0) { throw 'Native test fixture failed to compile.' }
    } else {
        $shellProbe = @'
#!/bin/sh
echo v24.19.0
sleep 1
if [ "$QUOTA_NODE_PROBE_FAIL" = 1 ]; then exit 7; fi
exit 0
'@
        [IO.File]::WriteAllText($candidate, $shellProbe.Replace("`r`n", "`n") + "`n")
        & chmod 755 $candidate
        if ($LASTEXITCODE -ne 0) { throw 'Native test fixture is not executable.' }
    }
    # Exclude an installed node.exe fallback so rejection cannot pass by accident.
    $env:PATH = if ($env:OS -eq 'Windows_NT') { Join-Path $env:WINDIR 'System32' } else { '/bin:/usr/bin' }
    $global:LASTEXITCODE = $null
    $found = Find-WidgetNode $scratch
    if ($found -cne [IO.Path]::GetFullPath($candidate)) { throw 'Fresh startup rejected Node 24 before its version probe exited.' }
    Write-Output 'PASS fresh startup waits for the native Node version probe to exit'
    $env:QUOTA_NODE_PROBE_FAIL = '1'
    $global:LASTEXITCODE = 0
    if ($null -ne (Find-WidgetNode $scratch)) { throw 'Version text with a failed native exit was accepted.' }
    Write-Output 'PASS Node version text with a nonzero exit stays rejected'
} finally {
    $env:PATH = $oldPath
    Remove-Item Env:QUOTA_NODE_PROBE_FAIL -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
