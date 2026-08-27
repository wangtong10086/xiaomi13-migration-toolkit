[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9._:-]+$')][string]$Serial,
    [string]$ExpectedProduct = 'fuxi',
    [ValidateSet('adb','fastboot')][string]$Mode = 'adb'
)

$ErrorActionPreference = 'Stop'

if ($Mode -eq 'adb') {
    $row = & adb devices | Where-Object { $_ -eq "$Serial`tdevice" }
    if (-not $row) { throw "Expected authorized adb target '$Serial' was not found." }
    $product = (& adb -s $Serial shell getprop ro.product.device).Trim()
} else {
    $row = & fastboot devices | Where-Object { ($_ -split '\s+')[0] -eq $Serial }
    if (-not $row) { throw "Expected fastboot target '$Serial' was not found." }
    $result = & fastboot -s $Serial getvar product 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Unable to read fastboot product: $($result -join ' ')" }
    $match = $result | Select-String -Pattern 'product:\s*(\S+)'
    $product = if ($match) { $match.Matches[0].Groups[1].Value } else { '' }
}

if ($product -ne $ExpectedProduct) {
    throw "Target product mismatch: expected '$ExpectedProduct', got '$product'."
}

[pscustomobject]@{ Serial = $Serial; Mode = $Mode; Product = $product; Validated = $true }
