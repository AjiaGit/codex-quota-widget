param(
    [Parameter(Mandatory=$true)][string]$NodeRoot,
    [string]$OutputDir = $env:OUTPUT_DIR,
    [string]$Version = $env:VERSION,
    [string]$IsccPath,
    [string]$ChineseMessages
)
$ErrorActionPreference = 'Stop'
$repository = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
if (-not $OutputDir) { throw 'Specify -OutputDir or OUTPUT_DIR outside the repository.' }
if (-not $Version) { $Version = '0.1.0' }
if ($Version -notmatch '^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$') { throw 'Version must be a semantic version.' }
$output = [IO.Path]::GetFullPath($OutputDir)
if ($output.TrimEnd('\','/') -eq $repository.TrimEnd('\','/') -or $output.StartsWith($repository.TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Build output must be outside the repository.' }
$nodeRootPath = [IO.Path]::GetFullPath($NodeRoot)
$node = Join-Path $nodeRootPath 'node.exe'; $nodeLicense = Join-Path $nodeRootPath 'LICENSE'
if (-not (Test-Path -LiteralPath $node -PathType Leaf) -or -not (Test-Path -LiteralPath $nodeLicense -PathType Leaf)) { throw 'NodeRoot must contain the official extracted node.exe and LICENSE.' }
$nodeVersion = & $node --version
if ($LASTEXITCODE -ne 0 -or $nodeVersion -notmatch '^v24\.') { throw 'Bundle the official Node.js 24 Windows x64 runtime.' }
if (-not $IsccPath) {
    $iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($iscc) { $IsccPath = $iscc.Source }
    else {
        foreach ($base in @(${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
            if ($base) { $candidate = Join-Path $base 'Inno Setup 6/ISCC.exe'; if (Test-Path -LiteralPath $candidate) { $IsccPath = $candidate; break } }
        }
    }
}
if (-not $IsccPath -or -not (Test-Path -LiteralPath $IsccPath -PathType Leaf)) { throw 'Install Inno Setup 6 and provide -IsccPath if it is not on PATH.' }
$csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { $csc = Join-Path $env:SystemRoot 'Microsoft.NET/Framework/v4.0.30319/csc.exe' }
if (-not (Test-Path -LiteralPath $csc)) { throw 'The Windows .NET Framework C# compiler was not found.' }
[void][IO.Directory]::CreateDirectory($output)
$payload = Join-Path $output 'windows-payload'
if (Test-Path -LiteralPath $payload) { Remove-Item -LiteralPath $payload -Recurse -Force }
[void][IO.Directory]::CreateDirectory($payload)
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $repository 'windows') -File) {
    if ($file.Extension -in @('.ps1','.cmd','.mjs','.ico')) { Copy-Item -LiteralPath $file.FullName -Destination $payload }
}
Copy-Item -LiteralPath (Join-Path $repository 'windows/public') -Destination $payload -Recurse
foreach ($name in @('LICENSE','THIRD_PARTY_NOTICES.md')) { Copy-Item -LiteralPath (Join-Path $repository $name) -Destination $payload }
[void][IO.Directory]::CreateDirectory((Join-Path $payload 'runtime'))
Copy-Item -LiteralPath $node -Destination (Join-Path $payload 'runtime/node.exe')
Copy-Item -LiteralPath $nodeLicense -Destination (Join-Path $payload 'runtime/LICENSE')
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'QuotaIconBuilder.cs') -ReferencedAssemblies System.Drawing
[QuotaIconBuilder]::Write((Join-Path $payload 'CodexQuota.ico'))
# Compile a native GUI launcher so opening the installed app does not flash a console.
& $csc /nologo /target:winexe /platform:x64 ('/out:' + (Join-Path $payload 'CodexQuotaWidget.exe')) ('/win32icon:' + (Join-Path $payload 'CodexQuota.ico')) /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Native launcher compilation failed.' }
$versionNumber = ($Version -split '[-+]')[0]
$compilerArgs = @(('/DAppVersion=' + $Version), ('/DVersionNumber=' + $versionNumber), ('/DPayloadDir=' + $payload), ('/DOutputDirectory=' + $output))
if (-not $ChineseMessages) { $ChineseMessages = Join-Path (Split-Path $IsccPath -Parent) 'Languages/ChineseSimplified.isl' }
if (Test-Path -LiteralPath $ChineseMessages) { $compilerArgs += '/DChineseMessages=' + [IO.Path]::GetFullPath($ChineseMessages) }
& $IsccPath @compilerArgs (Join-Path $PSScriptRoot 'CodexQuotaWidget.iss')
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compilation failed.' }
$installer = Join-Path $output ("CodexQuotaWidget-$Version-windows-x64.exe")
if (-not (Test-Path -LiteralPath $installer)) { throw 'The compiler did not produce the expected installer.' }
Get-FileHash -LiteralPath $installer -Algorithm SHA256 | ForEach-Object { ($_.Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($installer)) } | Set-Content -LiteralPath ($installer + '.sha256') -Encoding ASCII
Write-Output $installer
