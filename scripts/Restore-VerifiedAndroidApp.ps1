[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$AdbPath,
    [ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$SourceSerial,
    [string]$ApkPath,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$TargetSerial,
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._]+$')][string]$Package,
    [Parameter(Mandatory)][ValidatePattern('^[0-9a-fA-F]{64}$')][string]$ExpectedBaseSha256,
    [Parameter(Mandatory)][string]$WorkDir,
    [switch]$Install
)

$ErrorActionPreference = 'Stop'
if ([bool]$SourceSerial -eq [bool]$ApkPath) { throw 'Specify exactly one of SourceSerial or ApkPath.' }
if ($SourceSerial -and $SourceSerial -eq $TargetSerial) { throw 'Source and target serials must differ.' }
$adb = (Resolve-Path -LiteralPath $AdbPath).Path

foreach ($serial in @($SourceSerial,$TargetSerial) | Where-Object { $_ }) {
    $state = (& $adb -s $serial get-state 2>&1).Trim()
    if ($LASTEXITCODE -ne 0 -or $state -ne 'device') { throw "ADB device not ready: $serial ($state)" }
    $product = (& $adb -s $serial shell getprop ro.product.device).Trim()
    if ($product -ne 'fuxi') { throw "Unexpected product for ${serial}: $product" }
}

$work = [IO.Path]::GetFullPath($WorkDir)
New-Item -ItemType Directory -Path $work -Force | Out-Null
if ($SourceSerial) {
    $packagePaths = @(
        @(& $adb -s $SourceSerial shell pm path $Package) | ForEach-Object {
            if ($_ -match '^package:(.+)$') { $Matches[1].Trim() }
        } | Where-Object { $_ }
    )
    if ($packagePaths.Count -ne 1 -or -not $packagePaths[0].EndsWith('/base.apk')) {
        throw "Expected exactly one base APK for $Package; split packages require an explicit manifest workflow."
    }
    $localApk = Join-Path $work "$Package-base.apk"
    & $adb -s $SourceSerial pull $packagePaths[0] $localApk
    if ($LASTEXITCODE -ne 0) { throw 'ADB pull failed.' }
} else {
    $localApk = (Resolve-Path -LiteralPath $ApkPath).Path
}
$hash = (Get-FileHash -LiteralPath $localApk -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne $ExpectedBaseSha256.ToLowerInvariant()) {
    throw "APK SHA-256 mismatch: expected $ExpectedBaseSha256, got $hash"
}

if ($Install) {
    $result = & $adb -s $TargetSerial install --no-streaming -r $localApk 2>&1
    if ($LASTEXITCODE -ne 0 -or $result -notcontains 'Success') { throw "Install failed: $($result -join ' ')" }
    $targetPath = ((& $adb -s $TargetSerial shell pm path $Package) -replace '^package:','').Trim()
    if (-not $targetPath) { throw 'Target package has no code path after install.' }
    $remoteHash = ((& $adb -s $TargetSerial shell sha256sum $targetPath) -split '\s+')[0].ToLowerInvariant()
    if ($remoteHash -ne $hash) { throw "Installed APK hash mismatch: expected $hash, got $remoteHash" }
}

[pscustomobject]@{
    Package = $Package
    SourceSerial = $SourceSerial
    TargetSerial = $TargetSerial
    Apk = $localApk
    Sha256 = $hash
    Installed = [bool]$Install
}
