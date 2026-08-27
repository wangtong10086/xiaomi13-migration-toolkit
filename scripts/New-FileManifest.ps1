[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Root,
    [Parameter(Mandatory)][string]$OutputPath
)

$ErrorActionPreference = 'Stop'
$rootPath = [IO.Path]::GetFullPath($Root).TrimEnd('\')
if (-not (Test-Path -LiteralPath $rootPath -PathType Container)) { throw "Root not found: $rootPath" }
$outputFull = [IO.Path]::GetFullPath($OutputPath)

$files = Get-ChildItem -LiteralPath $rootPath -Recurse -File | Where-Object FullName -ne $outputFull | Sort-Object FullName
$entries = foreach ($file in $files) {
    [ordered]@{
        path = $file.FullName.Substring($rootPath.Length + 1).Replace('\','/')
        length = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$manifest = [ordered]@{ schema = 1; root = $rootPath; generatedAtUtc = [DateTime]::UtcNow.ToString('o'); files = @($entries) }
$parent = [IO.Path]::GetDirectoryName($outputFull)
if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputFull -Encoding utf8NoBOM
Write-Output $outputFull
