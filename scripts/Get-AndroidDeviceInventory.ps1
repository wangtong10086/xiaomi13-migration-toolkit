[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$Serial,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Invoke-AdbText {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $text = & adb -s $Serial @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "adb failed: $($text -join [Environment]::NewLine)" }
    ($text -join "`n").Trim()
}

$states = & adb devices
if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate adb devices.' }
if (-not ($states | Select-String -SimpleMatch "$Serial`tdevice")) {
    throw "Device '$Serial' is not connected and authorized in adb mode."
}

$props = [ordered]@{}
foreach ($name in @(
    'ro.product.device',
    'ro.product.model',
    'ro.boot.hardware',
    'ro.build.fingerprint',
    'ro.build.version.release',
    'ro.build.version.sdk',
    'ro.boot.slot_suffix',
    'ro.boot.verifiedbootstate',
    'ro.boot.flash.locked',
    'ro.boot.vbmeta.device_state',
    'ro.boot.dynamic_partitions'
)) {
    $props[$name] = Invoke-AdbText -Arguments @('shell', 'getprop', $name)
}

$inventory = [ordered]@{
    schema = 1
    capturedAtUtc = [DateTime]::UtcNow.ToString('o')
    serial = $Serial
    properties = $props
    bootCompleted = Invoke-AdbText -Arguments @('shell', 'getprop', 'sys.boot_completed')
    selinux = Invoke-AdbText -Arguments @('shell', 'getenforce')
    storage = Invoke-AdbText -Arguments @('shell', 'df', '-k', '/data')
    partitions = Invoke-AdbText -Arguments @('shell', 'ls', '-1', '/dev/block/by-name')
}

$fullOutput = [IO.Path]::GetFullPath($OutputPath)
$parent = [IO.Path]::GetDirectoryName($fullOutput)
if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
$inventory | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $fullOutput -Encoding utf8NoBOM
Write-Output $fullOutput
