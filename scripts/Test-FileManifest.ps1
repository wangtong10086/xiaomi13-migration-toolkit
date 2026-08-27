[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath)

$ErrorActionPreference = 'Stop'
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1) { throw "Unsupported manifest schema: $($manifest.schema)" }
$root = [IO.Path]::GetFullPath([string]$manifest.root).TrimEnd('\')
$failures = [Collections.Generic.List[string]]::new()

foreach ($entry in $manifest.files) {
    $relative = ([string]$entry.path).Replace('/', '\')
    $path = [IO.Path]::GetFullPath((Join-Path $root $relative))
    if (-not $path.StartsWith($root + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $failures.Add("Path escapes manifest root: $relative")
        continue
    }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $failures.Add("Missing: $relative")
        continue
    }
    $file = Get-Item -LiteralPath $path
    if ($file.Length -ne [long]$entry.length) { $failures.Add("Length mismatch: $relative") }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hash -ne [string]$entry.sha256) { $failures.Add("SHA-256 mismatch: $relative") }
}

if ($failures.Count) { throw ($failures -join [Environment]::NewLine) }
[pscustomobject]@{ Manifest = [IO.Path]::GetFullPath($ManifestPath); Files = @($manifest.files).Count; Verified = $true }
