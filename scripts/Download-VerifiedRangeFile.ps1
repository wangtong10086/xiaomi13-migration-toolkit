param(
    [Parameter(Mandatory = $true)][string]$Url,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][long]$ExpectedLength,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Fa-f0-9]+$')][string]$ExpectedHash,
    [ValidateSet('SHA256', 'SHA512', 'MD5')][string]$Algorithm = 'SHA256',
    [ValidateRange(1, 32)][int]$Segments = 16,
    [ValidateRange(1, 10)][int]$MaxAttempts = 5
)

$ErrorActionPreference = 'Stop'
$destinationPath = [IO.Path]::GetFullPath($Destination)
$destinationDirectory = [IO.Path]::GetDirectoryName($destinationPath)
$segmentDirectory = Join-Path $destinationDirectory ('.segments-' + $ExpectedHash.ToLowerInvariant())
$assembledPath = $destinationPath + '.clean.tmp'

function Assert-InDownloadArea([string]$Path) {
    $full = [IO.Path]::GetFullPath($Path)
    $root = $destinationDirectory.TrimEnd('\') + '\'
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing file operation outside download directory: $full"
    }
}

function Remove-DownloadTemp([string]$Path) {
    Assert-InDownloadArea $Path
    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
}

New-Item -ItemType Directory -Force -Path $segmentDirectory | Out-Null
$segmentSize = [long][Math]::Ceiling($ExpectedLength / [double]$Segments)
$jobs = [Collections.Generic.List[object]]::new()

for ($index = 0; $index -lt $Segments; $index++) {
    $start = [long]$index * $segmentSize
    $end = [Math]::Min($ExpectedLength - 1, $start + $segmentSize - 1)
    $part = Join-Path $segmentDirectory ('part-{0:D2}.bin' -f $index)
    $temp = $part + '.download'
    $expectedPartLength = $end - $start + 1
    $complete = (Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part).Length -eq $expectedPartLength)
    $jobs.Add([pscustomobject]@{
        Index = $index; Start = $start; End = $end; ExpectedLength = $expectedPartLength
        Part = $part; Temp = $temp; Attempts = 0; Process = $null; Complete = $complete
    })
}

function Start-Segment($Job) {
    $Job.Attempts++
    Remove-DownloadTemp $Job.Temp
    $arguments = @(
        '-L', '--fail', '--silent', '--show-error',
        '--range', "$($Job.Start)-$($Job.End)",
        '--output', $Job.Temp,
        $Url
    )
    $Job.Process = Start-Process -FilePath "$env:SystemRoot\System32\curl.exe" -ArgumentList $arguments -PassThru -WindowStyle Hidden
}

foreach ($job in $jobs) {
    if (-not $job.Complete) { Start-Segment $job }
}

while (@($jobs | Where-Object { -not $_.Complete }).Count -gt 0) {
    foreach ($job in $jobs | Where-Object { -not $_.Complete -and $_.Process -and $_.Process.HasExited }) {
        $length = if (Test-Path -LiteralPath $job.Temp) { (Get-Item -LiteralPath $job.Temp).Length } else { -1 }
        if ($job.Process.ExitCode -eq 0 -and $length -eq $job.ExpectedLength) {
            Assert-InDownloadArea $job.Temp
            Assert-InDownloadArea $job.Part
            Move-Item -LiteralPath $job.Temp -Destination $job.Part -Force
            $job.Complete = $true
            Write-Output ("Segment {0:D2} complete ({1} bytes)" -f $job.Index, $length)
        } elseif ($job.Attempts -lt $MaxAttempts) {
            Write-Output ("Segment {0:D2} retry {1}: exit={2}, length={3}, expected={4}" -f $job.Index, ($job.Attempts + 1), $job.Process.ExitCode, $length, $job.ExpectedLength)
            Start-Segment $job
        } else {
            throw "Segment $($job.Index) failed after $MaxAttempts attempts."
        }
    }

    $downloaded = [long](($jobs | ForEach-Object {
        if ($_.Complete) { $_.ExpectedLength }
        elseif (Test-Path -LiteralPath $_.Temp) { (Get-Item -LiteralPath $_.Temp).Length }
        else { 0 }
    } | Measure-Object -Sum).Sum)
    Write-Progress -Activity 'Downloading verified file' -Status "$downloaded / $ExpectedLength bytes" -PercentComplete (100 * $downloaded / $ExpectedLength)
    Start-Sleep -Seconds 5
}

Write-Progress -Activity 'Downloading verified file' -Completed
Remove-DownloadTemp $assembledPath
$hasher = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
if (-not $hasher) { throw "Unable to create hash algorithm: $Algorithm" }
$output = [IO.File]::Open($assembledPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
$buffer = New-Object byte[] (8MB)
try {
    foreach ($job in $jobs | Sort-Object Index) {
        $input = [IO.File]::OpenRead($job.Part)
        try {
            while (($read = $input.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $output.Write($buffer, 0, $read)
                [void]$hasher.TransformBlock($buffer, 0, $read, $null, 0)
            }
        } finally {
            $input.Dispose()
        }
    }
    [void]$hasher.TransformFinalBlock([byte[]]::new(0), 0, 0)
} finally {
    $output.Dispose()
}

$actualLength = (Get-Item -LiteralPath $assembledPath).Length
$actualHash = ([BitConverter]::ToString($hasher.Hash)).Replace('-', '')
$hasher.Dispose()
if ($actualLength -ne $ExpectedLength) { throw "Assembled length mismatch: $actualLength" }
if (-not $actualHash.Equals($ExpectedHash, [StringComparison]::OrdinalIgnoreCase)) { throw "Assembled $Algorithm mismatch: $actualHash" }

if (Test-Path -LiteralPath $destinationPath) {
    $oldLength = (Get-Item -LiteralPath $destinationPath).Length
    $quarantine = $destinationPath + ".corrupt-overlap-$oldLength"
    Assert-InDownloadArea $destinationPath
    Assert-InDownloadArea $quarantine
    if (Test-Path -LiteralPath $quarantine) { throw "Quarantine target already exists: $quarantine" }
    Move-Item -LiteralPath $destinationPath -Destination $quarantine
}

Assert-InDownloadArea $assembledPath
Assert-InDownloadArea $destinationPath
Move-Item -LiteralPath $assembledPath -Destination $destinationPath

[pscustomobject]@{
    Destination = $destinationPath
    Length = $ExpectedLength
    Algorithm = $Algorithm
    Hash = $actualHash
    Verified = $true
    SegmentsRetained = $segmentDirectory
}
